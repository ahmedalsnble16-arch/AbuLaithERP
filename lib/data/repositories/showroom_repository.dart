import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/showroom_daily_entry.dart';

class ShowroomRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // ========== دوال مساعدة ==========

  /// التحقق من حالة إغلاق اليومية
  Future<bool> isDayClosed(String businessDate) async {
    final account = await getDailyAccount(businessDate);
    if (account == null) return false;
    return (account['closed'] as int? ?? 0) == 1;
  }

  /// التحقق من إغلاق اليومية ورمي استثناء إذا كانت مغلقة
  Future<void> _ensureDayOpen(String businessDate) async {
    if (await isDayClosed(businessDate)) {
      throw Exception('لا يمكن التعديل على يومية مغلقة');
    }
  }

  // ========== ١. إدخالات الحركة اليومية ==========

  Future<ShowroomDailyEntry?> getEntry(String date, String productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableShowroomDailyEntries,
      where: 'business_date = ? AND product_id = ?',
      whereArgs: [date, productId],
    );
    if (maps.isEmpty) return null;
    return ShowroomDailyEntry.fromMap(maps.first);
  }

  /// جلب مدور آخر يوم سابق للتاريخ المطلوب باستعلام واحد محسن (JOIN)
  Future<int> getLastRemainingBeforeDate(String businessDate, String productId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT e.remaining_boxes, e.remaining_pieces, COALESCE(p.pieces_per_box, 60) as box_size
      FROM ${DBConstants.tableShowroomDailyEntries} e
      LEFT JOIN ${DBConstants.tableProducts} p ON e.product_id = p.id
      WHERE e.business_date < ? AND e.product_id = ?
      ORDER BY e.business_date DESC
      LIMIT 1
    ''', [businessDate, productId]);

    if (result.isEmpty) return 0;
    
    final remainingBoxes = result.first['remaining_boxes'] as int? ?? 0;
    final remainingPieces = result.first['remaining_pieces'] as int? ?? 0;
    final boxSize = result.first['box_size'] as int? ?? 60;
    
    return (remainingBoxes * boxSize) + remainingPieces;
  }

  Future<int> getYesterdayRemaining(String todayDate, String productId) async {
    return await getLastRemainingBeforeDate(todayDate, productId);
  }

  Future<List<ShowroomDailyEntry>> getDailyEntries(String businessDate) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableShowroomDailyEntries,
      where: 'business_date = ?',
      whereArgs: [businessDate],
    );
    return maps.map((m) => ShowroomDailyEntry.fromMap(m)).toList();
  }

  /// حفظ جميع إدخالات اليوم في Transaction واحدة
  Future<void> saveAllEntries({
    required String businessDate,
    required List<Map<String, dynamic>> entries,
    String? createdBy,
    String? deviceId,
  }) async {
    if (entries.isEmpty) return;
    await _ensureDayOpen(businessDate);

    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;

    await db.transaction((txn) async {
      for (var entry in entries) {
        final productId = entry['productId'] as String;
        final loadBoxes = entry['loadBoxes'] as int;
        final loadPieces = entry['loadPieces'] as int;
        final returnBoxes = entry['returnBoxes'] as int;
        final returnPieces = entry['returnPieces'] as int;
        final boxSize = entry['boxSize'] as int;
        final retailPrice = entry['retailPrice'] as double;

        // جلب القديم لحساب الفروقات
        final existingMaps = await txn.query(
          DBConstants.tableShowroomDailyEntries,
          where: 'business_date = ? AND product_id = ?',
          whereArgs: [businessDate, productId],
        );
        final existing = existingMaps.isNotEmpty ? ShowroomDailyEntry.fromMap(existingMaps.first) : null;

        final loadTotalPieces = (loadBoxes * boxSize) + loadPieces;
        final returnTotalPieces = (returnBoxes * boxSize) + returnPieces;

        final oldLoad = existing?.loadTotalPieces ?? 0;
        final oldReturn = existing?.returnTotalPieces ?? 0;
        final netLoadDiff = loadTotalPieces - oldLoad;
        final netReturnDiff = returnTotalPieces - oldReturn;

        // تحديث المخزون بالفروقات فقط
        if (netLoadDiff != 0) {
          if (netLoadDiff > 0) {
            await _deductFromProductionStock(txn, productId, netLoadDiff, businessDate, createdBy, deviceId);
          } else {
            await _addToProductionStock(txn, productId, -netLoadDiff, businessDate, createdBy, deviceId);
          }
        }
        if (netReturnDiff != 0) {
          if (netReturnDiff > 0) {
            await _addToProductionStock(txn, productId, netReturnDiff, businessDate, createdBy, deviceId);
          } else {
            await _deductFromProductionStock(txn, productId, -netReturnDiff, businessDate, createdBy, deviceId);
          }
        }

        final loadValue = loadTotalPieces * retailPrice;
        final returnValue = returnTotalPieces * retailPrice;
        final netValue = loadValue - returnValue;

        // حساب مدور الأمس داخل المعاملة
        final previousMaps = await txn.query(
          DBConstants.tableShowroomDailyEntries,
          columns: ['remaining_boxes', 'remaining_pieces'],
          where: 'business_date < ? AND product_id = ?',
          whereArgs: [businessDate, productId],
          orderBy: 'business_date DESC',
          limit: 1,
        );
        int previousRemaining = 0;
        if (previousMaps.isNotEmpty) {
          final remBoxes = previousMaps.first['remaining_boxes'] as int? ?? 0;
          final remPieces = previousMaps.first['remaining_pieces'] as int? ?? 0;
          previousRemaining = (remBoxes * boxSize) + remPieces;
        }

        final remainingTotalPieces = previousRemaining + loadTotalPieces - returnTotalPieces;
        final remainingBoxes = remainingTotalPieces ~/ boxSize;
        final remainingPieces = remainingTotalPieces % boxSize;
        final remainingValue = remainingTotalPieces * retailPrice;

        final entryData = {
          'business_date': businessDate,
          'product_id': productId,
          'load_boxes': loadBoxes,
          'load_pieces': loadPieces,
          'load_total_pieces': loadTotalPieces,
          'return_boxes': returnBoxes,
          'return_pieces': returnPieces,
          'return_total_pieces': returnTotalPieces,
          'load_value': loadValue,
          'return_value': returnValue,
          'net_value': netValue,
          'remaining_boxes': remainingBoxes,
          'remaining_pieces': remainingPieces,
          'remaining_value': remainingValue,
          'updated_at': now,
        };

        if (existing != null) {
          await txn.update(
            DBConstants.tableShowroomDailyEntries,
            entryData,
            where: 'id = ?',
            whereArgs: [existing.id],
          );
        } else {
          entryData['id'] = _uuid.v4();
          entryData['created_at'] = now;
          await txn.insert(DBConstants.tableShowroomDailyEntries, entryData);
        }

        // تدقيق
        await txn.insert(DBConstants.tableAuditLogs, {
          'id': _uuid.v4(),
          'user_id': createdBy,
          'module': 'المعرض',
          'action': 'تسجيل حركة يومية',
          'new_data': 'سحب $loadTotalPieces، مرتجع $returnTotalPieces للمنتج $productId بتاريخ $businessDate',
          'device_id': deviceId,
          'created_at': now,
        });
      }
    });
  }

  Future<void> saveEntry({
    required String businessDate,
    required String productId,
    required int loadBoxes,
    required int loadPieces,
    required int returnBoxes,
    required int returnPieces,
    required int boxSize,
    required double retailPrice,
    String? createdBy,
    String? deviceId,
  }) async {
    await saveAllEntries(
      businessDate: businessDate,
      entries: [{
        'productId': productId,
        'loadBoxes': loadBoxes,
        'loadPieces': loadPieces,
        'returnBoxes': returnBoxes,
        'returnPieces': returnPieces,
        'boxSize': boxSize,
        'retailPrice': retailPrice,
      }],
      createdBy: createdBy,
      deviceId: deviceId,
    );
  }

  Future<void> _deductFromProductionStock(DatabaseExecutor txn, String productId,
      int quantity, String businessDate, String? userId, String? deviceId) async {
    final stock = await txn.query(DBConstants.tableStock,
        where: 'product_id = ?', whereArgs: [productId]);
    if (stock.isEmpty) throw Exception('المنتج غير موجود في مخزن الإنتاج');
    final currentQty = stock.first['quantity_pieces'] as int? ?? 0;
    if (quantity > currentQty) {
      throw Exception('الكمية المطلوبة ($quantity) أكبر من المتاح ($currentQty)');
    }

    await txn.update(DBConstants.tableStock, {
      'quantity_pieces': currentQty - quantity,
      'updated_at': DatabaseHelper.now,
    }, where: 'product_id = ?', whereArgs: [productId]);

    await txn.insert(DBConstants.tableStockMovements, {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': 'تحويل',
      'quantity': -quantity,
      'before_qty': currentQty,
      'after_qty': currentQty - quantity,
      'reference_id': businessDate,
      'reference_type': 'showroom',
      'notes': 'سحب معرض بتاريخ $businessDate',
      'created_at': DatabaseHelper.now,
      'created_by': userId,
      'device_id': deviceId,
      'sync_status': 'Pending',
    });
  }

  Future<void> _addToProductionStock(DatabaseExecutor txn, String productId,
      int quantity, String businessDate, String? userId, String? deviceId) async {
    final stock = await txn.query(DBConstants.tableStock,
        where: 'product_id = ?', whereArgs: [productId]);
    final now = DatabaseHelper.now;
    int beforeQty = 0;
    if (stock.isNotEmpty) {
      beforeQty = stock.first['quantity_pieces'] as int? ?? 0;
      await txn.update(DBConstants.tableStock, {
        'quantity_pieces': beforeQty + quantity,
        'updated_at': now,
      }, where: 'product_id = ?', whereArgs: [productId]);
    } else {
      await txn.insert(DBConstants.tableStock, {
        'id': _uuid.v4(),
        'product_id': productId,
        'quantity_pieces': quantity,
        'reserved_quantity': 0,
        'average_cost': 0,
        'last_update': now,
        'created_at': now,
        'updated_at': now,
      });
    }

    await txn.insert(DBConstants.tableStockMovements, {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': 'مرتجع',
      'quantity': quantity,
      'before_qty': beforeQty,
      'after_qty': beforeQty + quantity,
      'reference_id': businessDate,
      'reference_type': 'showroom',
      'notes': 'مرتجع معرض بتاريخ $businessDate',
      'created_at': now,
      'created_by': userId,
      'device_id': deviceId,
      'sync_status': 'Pending',
    });
  }

  // ========== ٢. العمال والمصاريف ==========

  Future<List<Map<String, dynamic>>> getActiveWorkers() async {
    final db = await _dbHelper.database;
    return await db.query(DBConstants.tableWorkers,
        where: 'active = 1 AND deleted = 0', orderBy: 'name ASC');
  }

  Future<Map<String, bool>> getWorkerAttendance(String date) async {
    final db = await _dbHelper.database;
    final rows = await db.query(DBConstants.tableWorkerAttendance,
        where: 'date = ?', whereArgs: [date]);
    final map = <String, bool>{};
    for (var r in rows) {
      map[r['worker_id'] as String] = true;
    }
    return map;
  }

  Future<void> setWorkerAttendance({
    required String workerId,
    required String date,
    required bool present,
  }) async {
    await _ensureDayOpen(date);
    final db = await _dbHelper.database;
    if (present) {
      await db.rawInsert('''
        INSERT OR REPLACE INTO ${DBConstants.tableWorkerAttendance} (id, worker_id, date, created_at)
        VALUES (?, ?, ?, ?)
      ''', [_uuid.v4(), workerId, date, DatabaseHelper.now]);
    } else {
      await db.delete(DBConstants.tableWorkerAttendance,
          where: 'worker_id = ? AND date = ?', whereArgs: [workerId, date]);
    }
  }

  Future<void> saveWorkerAdvance({
    required String workerId,
    required double amount,
    required String date,
    String? createdBy,
    String? deviceId,
  }) async {
    await _ensureDayOpen(date);
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    await db.insert(DBConstants.tableWorkerAccounts, {
      'id': _uuid.v4(),
      'worker_id': workerId,
      'transaction_type': 'سلفة (برانية)',
      'amount': amount,
      'description': 'برانية من المعرض بتاريخ $date',
      'transaction_date': date,
      'created_at': now,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': 'Pending',
    });
  }

  Future<List<Map<String, dynamic>>> getWorkerAdvances(String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT wa.*, w.name as worker_name
      FROM ${DBConstants.tableWorkerAccounts} wa
      JOIN ${DBConstants.tableWorkers} w ON wa.worker_id = w.id
      WHERE wa.transaction_type = 'سلفة (برانية)'
        AND wa.transaction_date = ?
      ORDER BY wa.created_at
    ''', [date]);
  }

  // ========== ٣. الخرج اليومي ==========

  Future<List<Map<String, dynamic>>> getDailyExpenses(String businessDate, {String category = 'expense'}) async {
    final db = await _dbHelper.database;
    return await db.query(
      DBConstants.tableShowroomDailyExpenses,
      where: 'business_date = ? AND category = ?',
      whereArgs: [businessDate, category],
    );
  }

  Future<void> saveDailyExpenses({
    required String businessDate,
    required List<Map<String, dynamic>> expenses,
    String category = 'expense',
    String? createdBy,
    String? deviceId,
  }) async {
    await _ensureDayOpen(businessDate);
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    await db.transaction((txn) async {
      await txn.delete(
        DBConstants.tableShowroomDailyExpenses,
        where: 'business_date = ? AND category = ?',
        whereArgs: [businessDate, category],
      );
      for (var exp in expenses) {
        final amount = (exp['amount'] as num?)?.toDouble() ?? 0;
        final details = exp['details']?.toString() ?? '';
        if (amount > 0 || details.isNotEmpty) {
          await txn.insert(DBConstants.tableShowroomDailyExpenses, {
            'id': exp['id'] ?? _uuid.v4(),
            'business_date': businessDate,
            'category': category,
            'amount': amount,
            'details': details,
            'created_at': now,
            'created_by': createdBy,
            'device_id': deviceId,
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSmallLedger(String businessDate) async {
    return await getDailyExpenses(businessDate, category: 'small_ledger');
  }

  Future<void> saveSmallLedger({
    required String businessDate,
    required List<Map<String, dynamic>> entries,
    String? createdBy,
    String? deviceId,
  }) async {
    await _ensureDayOpen(businessDate);
    await saveDailyExpenses(
      businessDate: businessDate,
      expenses: entries,
      category: 'small_ledger',
      createdBy: createdBy,
      deviceId: deviceId,
    );
  }

  // ========== ٤. كشف الحساب الرسمي ==========

  Future<Map<String, dynamic>?> getDailyAccount(String businessDate) async {
    final db = await _dbHelper.database;
    final results = await db.query(DBConstants.tableShowroomDailyAccount,
        where: 'business_date = ?', whereArgs: [businessDate]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> saveDailyAccount({
    required String businessDate,
    required double previousRemainingValue,
    required double totalLoadValue,
    required double totalReturnValue,
    required double netGoodsValue,
    required double totalWorkerExpenses,
    required double totalWorkerAdvances,
    required double totalDailyExpenses,
    required double totalSmallLedger,
    required double otherIncome,
    required double showroomExpense,
    required double totalDue,
    required double cashReceived,
    required bool cashConfirmed,
    String? confirmedBy,
    required double resultAmount,
    required String resultStatus,
    bool closed = false,
    String? closedBy,
    String? createdBy,
    String? deviceId,
  }) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    final combinedDailyExpenses = totalDailyExpenses + totalSmallLedger;

    await db.transaction((txn) async {
      final data = {
        'business_date': businessDate,
        'previous_remaining_value': previousRemainingValue,
        'total_load_value': totalLoadValue,
        'total_return_value': totalReturnValue,
        'net_goods_value': netGoodsValue,
        'total_worker_expenses': totalWorkerExpenses,
        'total_worker_advances': totalWorkerAdvances,
        'total_daily_expenses': combinedDailyExpenses,
        'other_income': otherIncome,
        'showroom_expense': showroomExpense,
        'total_due': totalDue,
        'cash_received': cashReceived,
        'cash_confirmed': cashConfirmed ? 1 : 0,
        'confirmed_by': confirmedBy,
        'result_amount': resultAmount,
        'result_status': resultStatus,
        'closed': closed ? 1 : 0,
        'closed_by': closedBy,
        'closed_at': closed ? now : null,
        'updated_at': now,
      };

      final existing = await txn.query(
        DBConstants.tableShowroomDailyAccount,
        where: 'business_date = ?',
        whereArgs: [businessDate],
      );

      if (existing.isNotEmpty) {
        await txn.update(DBConstants.tableShowroomDailyAccount, data,
            where: 'business_date = ?', whereArgs: [businessDate]);
      } else {
        data['id'] = _uuid.v4();
        data['created_at'] = now;
        await txn.insert(DBConstants.tableShowroomDailyAccount, data);
      }

      if (closed) {
        // قيد الخزنة
        if (cashReceived > 0) {
          await txn.insert(DBConstants.tableTreasury, {
            'id': _uuid.v4(),
            'transaction_number': 'SHW-$businessDate-${DateTime.now().millisecondsSinceEpoch}',
            'transaction_type': DBConstants.txnTypeReceipt,
            'amount': cashReceived,
            'source_module': 'معرض',
            'source_id': businessDate,
            'payment_method': 'نقدي',
            'note': 'توريد نقدي من المعرض عن يوم $businessDate',
            'transaction_date': businessDate,
            'status': DBConstants.statusApproved,
            'approved_by': closedBy ?? createdBy,
            'created_at': now,
            'updated_at': now,
            'created_by': createdBy,
            'device_id': deviceId,
            'sync_status': 'Pending',
            'deleted': 0,
          });
        }

        // قيد الخرج اليومي (منفصل)
        if (totalDailyExpenses > 0) {
          await txn.insert(DBConstants.tableExpenses, {
            'id': _uuid.v4(),
            'title': 'مصاريف يومية - معرض $businessDate',
            'category': 'مصاريف معرض',
            'amount': totalDailyExpenses,
            'note': 'إجمالي الخرج اليومي للمعرض',
            'expense_date': businessDate,
            'status': DBConstants.statusApproved,
            'approved_by': closedBy ?? createdBy,
            'created_at': now,
            'updated_at': now,
            'created_by': createdBy,
            'device_id': deviceId,
            'sync_status': 'Pending',
            'deleted': 0,
          });
        }

        // قيد الكشف الصغير (منفصل)
        if (totalSmallLedger > 0) {
          await txn.insert(DBConstants.tableExpenses, {
            'id': _uuid.v4(),
            'title': 'كشف صغير - معرض $businessDate',
            'category': 'مصاريف معرض',
            'amount': totalSmallLedger,
            'note': 'إجمالي الكشف الصغير للمعرض',
            'expense_date': businessDate,
            'status': DBConstants.statusApproved,
            'approved_by': closedBy ?? createdBy,
            'created_at': now,
            'updated_at': now,
            'created_by': createdBy,
            'device_id': deviceId,
            'sync_status': 'Pending',
            'deleted': 0,
          });
        }

        // Audit للإغلاق
        await txn.insert(DBConstants.tableAuditLogs, {
          'id': _uuid.v4(),
          'user_id': createdBy,
          'module': 'المعرض',
          'action': 'إغلاق يومية المعرض',
          'new_data': 'تاريخ $businessDate، نتيجة ${resultAmount.toStringAsFixed(2)} ($resultStatus)',
          'device_id': deviceId,
          'created_at': now,
        });
      }
    });
  }

  Future<void> confirmCash({
    required String businessDate,
    required bool confirmed,
    String? confirmedBy,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableShowroomDailyAccount,
      {
        'cash_confirmed': confirmed ? 1 : 0,
        'confirmed_by': confirmed ? confirmedBy : null,
      },
      where: 'business_date = ?',
      whereArgs: [businessDate],
    );
  }

  Future<Map<String, dynamic>?> getPreviousDayAccount(String currentDate) async {
    final db = await _dbHelper.database;
    final results = await db.query(DBConstants.tableShowroomDailyAccount,
        where: 'business_date < ? AND closed = 1',
        whereArgs: [currentDate],
        orderBy: 'business_date DESC',
        limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getPreviousDayFull(String currentDate) async {
    return await getPreviousDayAccount(currentDate);
  }

  // ========== ٥. قات العمال ==========

  Future<List<Map<String, dynamic>>> getKhatEntries(String businessDate) async {
    final db = await _dbHelper.database;
    return await db.query(DBConstants.tableShowroomKhat,
        where: 'business_date = ?', whereArgs: [businessDate]);
  }

  Future<void> saveKhat({
    required String businessDate,
    required List<Map<String, dynamic>> entries,
    String? createdBy,
    String? deviceId,
  }) async {
    await _ensureDayOpen(businessDate);
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    await db.transaction((txn) async {
      await txn.delete(DBConstants.tableShowroomKhat,
          where: 'business_date = ?', whereArgs: [businessDate]);
      for (var e in entries) {
        final amount = (e['amount'] as num?)?.toDouble() ?? 0;
        final workerName = e['worker_name']?.toString() ?? '';
        if (amount > 0 || workerName.isNotEmpty) {
          await txn.insert(DBConstants.tableShowroomKhat, {
            'id': e['id'] ?? _uuid.v4(),
            'business_date': businessDate,
            'worker_name': workerName,
            'amount': amount,
            'created_at': now,
            'created_by': createdBy,
            'device_id': deviceId,
          });
        }
      }
    });
  }

  // ========== دوال تكميلية ==========

  Future<int> getAvailableStock(String productId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DBConstants.tableStock,
      columns: ['quantity_pieces', 'reserved_quantity'],
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    if (rows.isEmpty) return 0;
    final qty = rows.first['quantity_pieces'] as int? ?? 0;
    final reserved = rows.first['reserved_quantity'] as int? ?? 0;
    return qty - reserved;
  }

  Future<void> recordWorkerDailyExpense({
    required String workerId,
    required String date,
    required double amount,
    String? createdBy,
    String? deviceId,
  }) async {
    await _ensureDayOpen(date);
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    await db.insert(DBConstants.tableWorkerAccounts, {
      'id': _uuid.v4(),
      'worker_id': workerId,
      'transaction_type': 'مصروف يومي',
      'amount': amount,
      'description': 'مصروف يومي عن $date (حضور المعرض)',
      'transaction_date': date,
      'created_at': now,
      'created_by': createdBy,
      'device_id': deviceId,
      'sync_status': 'Pending',
    });
  }
}
