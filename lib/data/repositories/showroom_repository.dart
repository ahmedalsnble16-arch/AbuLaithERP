import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/showroom_daily_entry.dart';

class ShowroomRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

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

  // جلب مدور الأمس لمنتج معين
  Future<int> getYesterdayRemaining(String todayDate, String productId) async {
    final yesterday = DateTime.parse(todayDate)
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final entry = await getEntry(yesterday, productId);
    return entry?.remainingTotalPieces ?? 0;
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
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    final existing = await getEntry(businessDate, productId);

    final loadTotalPieces = (loadBoxes * boxSize) + loadPieces;
    final returnTotalPieces = (returnBoxes * boxSize) + returnPieces;
    final loadValue = loadTotalPieces * retailPrice;
    final returnValue = returnTotalPieces * retailPrice;
    final netValue = loadValue - returnValue;

    // المدور عليه = (مدور أمس) + سحب اليوم - مرتجع اليوم
    int previousRemaining = 0;
    if (existing != null) {
      previousRemaining = existing.remainingTotalPieces;
    } else {
      // جلب مدور أمس من جدول الإدخالات
      final yesterday = DateTime.parse(businessDate)
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final yesterdayEntry = await getEntry(yesterday, productId);
      if (yesterdayEntry != null) {
        previousRemaining = yesterdayEntry.remainingTotalPieces;
      }
    }

    final remainingTotalPieces = previousRemaining + loadTotalPieces - returnTotalPieces;
    final remainingBoxes = remainingTotalPieces ~/ boxSize;
    final remainingPieces = remainingTotalPieces % boxSize;
    final remainingValue = remainingTotalPieces * retailPrice;

    await db.transaction((txn) async {
      // خصم السحبيات من مخزن الإنتاج
      if (loadTotalPieces > 0) {
        await _deductFromProductionStock(
          txn, productId, loadTotalPieces, businessDate, createdBy, deviceId);
      }

      // إرجاع المرتجعات إلى مخزن الإنتاج
      if (returnTotalPieces > 0) {
        await _addToProductionStock(
          txn, productId, returnTotalPieces, businessDate, createdBy, deviceId);
      }

      // حفظ الحركة اليومية
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
    });
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
    final db = await _dbHelper.database;
    if (present) {
      try {
        await db.insert(DBConstants.tableWorkerAttendance, {
          'id': _uuid.v4(),
          'worker_id': workerId,
          'date': date,
          'created_at': DatabaseHelper.now,
        });
      } catch (_) {} // ignore duplicate
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
    // يمكن الاستعلام من worker_accounts إذا احتجنا، لكن الصفحة الحالية تستخدم المدخلات مباشرة
    return [];
  }

  // ========== ٣. الخرج اليومي ==========
  // جلب الخرج اليومي (مع إمكانية تصفية حسب الفئة)
  Future<List<Map<String, dynamic>>> getDailyExpenses(String businessDate, {String category = 'expense'}) async {
    final db = await _dbHelper.database;
    return await db.query(
      DBConstants.tableShowroomDailyExpenses,
      where: 'business_date = ? AND category = ?',
      whereArgs: [businessDate, category],
    );
  }

  // حفظ الخرج اليومي (مع تحديد الفئة)
  Future<void> saveDailyExpenses({
    required String businessDate,
    required List<Map<String, dynamic>> expenses,
    String category = 'expense',
    String? createdBy,
    String? deviceId,
  }) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    await db.transaction((txn) async {
      // حذف القديم لنفس اليوم ونفس الفئة
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

  // دوال خاصة بالكشف الصغير
  Future<List<Map<String, dynamic>>> getSmallLedger(String businessDate) async {
    return await getDailyExpenses(businessDate, category: 'small_ledger');
  }

  Future<void> saveSmallLedger({
    required String businessDate,
    required List<Map<String, dynamic>> entries,
    String? createdBy,
    String? deviceId,
  }) async {
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
    final data = {
      'business_date': businessDate,
      'previous_remaining_value': previousRemainingValue,
      'total_load_value': totalLoadValue,
      'total_return_value': totalReturnValue,
      'net_goods_value': netGoodsValue,
      'total_worker_expenses': totalWorkerExpenses,
      'total_worker_advances': totalWorkerAdvances,
      'total_daily_expenses': totalDailyExpenses,
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

    final existing = await getDailyAccount(businessDate);
    if (existing != null) {
      await db.update(DBConstants.tableShowroomDailyAccount, data,
          where: 'business_date = ?', whereArgs: [businessDate]);
    } else {
      data['id'] = _uuid.v4();
      data['created_at'] = now;
      await db.insert(DBConstants.tableShowroomDailyAccount, data);
    }

    // Audit log
    await db.insert(DBConstants.tableAuditLogs, {
      'id': _uuid.v4(),
      'user_id': createdBy,
      'module': 'المعرض',
      'action': closed ? 'إغلاق يومية المعرض' : 'تحديث كشف حساب المعرض',
      'new_data': 'تاريخ $businessDate، نتيجة ${resultAmount.toStringAsFixed(2)} ($resultStatus)',
      'device_id': deviceId,
      'created_at': now,
    });
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
}
