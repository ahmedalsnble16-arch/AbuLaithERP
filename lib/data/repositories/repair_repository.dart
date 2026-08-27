import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/repair.dart';

class RepairRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // ========== العمليات الأساسية ==========

  /// جلب جميع الإصلاحات مع الفلاتر
  Future<List<Repair>> getAll({
    String? dateFilter,
    String? typeFilter,
    String? searchQuery,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    String where = 'deleted = 0';
    List<dynamic> args = [];

    if (dateFilter != null && dateFilter.isNotEmpty) {
      where += ' AND repair_date = ?';
      args.add(dateFilter);
    }
    if (typeFilter != null && typeFilter.isNotEmpty) {
      where += ' AND repair_type = ?';
      args.add(typeFilter);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (description LIKE ? OR repair_type LIKE ? OR id LIKE ?)';
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }
    if (fromDate != null && fromDate.isNotEmpty && toDate != null && toDate.isNotEmpty) {
      where += ' AND repair_date BETWEEN ? AND ?';
      args.add(fromDate);
      args.add(toDate);
    }

    final maps = await db.query(
      DBConstants.tableRepairs,
      where: where,
      whereArgs: args,
      orderBy: 'repair_date DESC, created_at DESC',
    );
    return maps.map((m) => Repair.fromMap(m)).toList();
  }

  /// جلب أنواع الإصلاحات
  Future<List<String>> getRepairTypes() async {
    final db = await _dbHelper.database;
    final maps = await db.query(DBConstants.tableRepairTypes, orderBy: 'name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  // ========== الإضافة مع الربط بالخزنة ==========

  /// إضافة إصلاح مع ترحيل للخزنة
  Future<String> addRepair({
    required String repairType,
    required String description,
    required double amount,
    String? notes,
    String? repairDate,
    String? createdBy,
    String? deviceId,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final repairId = _uuid.v4();
    final treasuryId = _uuid.v4();
    final date = repairDate ?? now.toIso8601String().substring(0, 10);

    // التحقق من رصيد الخزنة
    final balanceResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN transaction_type = '${DBConstants.txnTypeReceipt}' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN transaction_type = '${DBConstants.txnTypePayment}' THEN amount ELSE 0 END), 0) as balance
      FROM ${DBConstants.tableTreasury}
      WHERE deleted = 0 AND status = '${DBConstants.statusApproved}'
    ''');
    final balance = (balanceResult.first['balance'] as num?)?.toDouble() ?? 0.0;
    
    if (amount > balance) {
      throw Exception('لا يوجد رصيد كافٍ في الخزنة. الرصيد الحالي: ${balance.toStringAsFixed(0)} ريال');
    }

    await db.transaction((txn) async {
      // 1. تسجيل الإصلاح
      await txn.insert(DBConstants.tableRepairs, {
        'id': repairId,
        'repair_type': repairType,
        'description': description,
        'amount': amount,
        'repair_date': date,
        'repair_time': now.toIso8601String().substring(11, 19),
        'notes': notes,
        'created_by': createdBy ?? 'admin',
        'treasury_transaction_id': treasuryId,
        'status': DBConstants.statusApproved,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'device_id': deviceId ?? 'mobile',
        'sync_status': DBConstants.syncPending,
        'deleted': 0,
      });

      // 2. ترحيل للخزنة (صرف)
      await txn.insert(DBConstants.tableTreasury, {
        'id': treasuryId,
        'transaction_number': 'REP-${now.millisecondsSinceEpoch}-${repairId.substring(0, 4)}',
        'transaction_type': DBConstants.txnTypePayment,
        'amount': amount,
        'source_module': 'الإصلاحات',
        'source_id': repairId,
        'payment_method': DBConstants.paymentCash,
        'note': '$repairType - $description',
        'transaction_date': date,
        'status': DBConstants.statusApproved,
        'approved_by': createdBy ?? 'admin',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'created_by': createdBy ?? 'admin',
        'device_id': deviceId ?? 'mobile',
        'sync_status': DBConstants.syncPending,
        'deleted': 0,
      });

      // 3. سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': createdBy ?? 'admin',
        'module': 'الإصلاحات',
        'action': 'إضافة إصلاح',
        'new_data': '$repairType - $description - $amount ريال',
        'device_id': deviceId ?? 'mobile',
        'created_at': now.toIso8601String(),
      });
    });

    return repairId;
  }

  // ========== الإحصائيات ==========

  /// إجمالي اليوم
  Future<double> getTodayTotal() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DBConstants.tableRepairs}
      WHERE repair_date = ? AND deleted = 0
    ''', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// إجمالي الشهر
  Future<double> getMonthTotal({int? month, int? year}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final m = (month ?? now.month).toString().padLeft(2, '0');
    final y = (year ?? now.year).toString();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DBConstants.tableRepairs}
      WHERE strftime('%m', repair_date) = ? AND strftime('%Y', repair_date) = ? AND deleted = 0
    ''', [m, y]);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// إجمالي السنة
  Future<double> getYearTotal({int? year}) async {
    final db = await _dbHelper.database;
    final y = (year ?? DateTime.now().year).toString();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DBConstants.tableRepairs}
      WHERE strftime('%Y', repair_date) = ? AND deleted = 0
    ''', [y]);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// الإجمالي الكلي
  Future<double> getTotalAll() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${DBConstants.tableRepairs} WHERE deleted = 0
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// عدد الإصلاحات
  Future<int> getCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ${DBConstants.tableRepairs} WHERE deleted = 0');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  // ========== الجرد الشهري ==========

  Future<List<Map<String, dynamic>>> getMonthlyReport({required int month, required int year}) async {
    final db = await _dbHelper.database;
    final m = month.toString().padLeft(2, '0');
    final y = year.toString();
    return await db.rawQuery('''
      SELECT id, repair_date, repair_type, description, amount, repair_time, created_by, treasury_transaction_id
      FROM ${DBConstants.tableRepairs}
      WHERE strftime('%m', repair_date) = ? AND strftime('%Y', repair_date) = ? AND deleted = 0
      ORDER BY repair_date ASC
    ''', [m, y]);
  }

  // ========== الجرد السنوي ==========

  Future<List<Map<String, dynamic>>> getYearlyReport({required int year}) async {
    final db = await _dbHelper.database;
    final y = year.toString();
    return await db.rawQuery('''
      SELECT 
        strftime('%m', repair_date) as month,
        COUNT(*) as count,
        COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableRepairs}
      WHERE strftime('%Y', repair_date) = ? AND deleted = 0
      GROUP BY strftime('%m', repair_date)
      ORDER BY month ASC
    ''', [y]);
  }

  // ========== التعديل مع تصحيح الخزنة ==========

  Future<void> updateRepair({
    required String repairId,
    required String repairType,
    required String description,
    required double newAmount,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final oldRepairs = await db.query(
      DBConstants.tableRepairs,
      where: 'id = ? AND deleted = 0',
      whereArgs: [repairId],
    );
    if (oldRepairs.isEmpty) throw Exception('الإصلاح غير موجود');

    final oldRepair = oldRepairs.first;
    final oldAmount = (oldRepair['amount'] as num?)?.toDouble() ?? 0;
    final treasuryId = oldRepair['treasury_transaction_id'] as String?;

    await db.transaction((txn) async {
      // تحديث الإصلاح
      await txn.update(DBConstants.tableRepairs, {
        'repair_type': repairType,
        'description': description,
        'amount': newAmount,
        'notes': notes,
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [repairId]);

      // تصحيح حركة الخزنة
      if (treasuryId != null) {
        await txn.update(DBConstants.tableTreasury, {
          'amount': newAmount,
          'note': '$repairType - $description',
          'updated_at': now,
        }, where: 'id = ?', whereArgs: [treasuryId]);
      }

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'الإصلاحات',
        'action': 'تعديل إصلاح',
        'old_data': 'المبلغ القديم: $oldAmount، النوع: ${oldRepair['repair_type']}',
        'new_data': 'المبلغ الجديد: $newAmount، النوع: $repairType',
        'created_at': now,
      });
    });
  }

  // ========== الإلغاء مع عكس حركة الخزنة ==========

  Future<void> cancelRepair(String repairId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final oldRepairs = await db.query(
      DBConstants.tableRepairs,
      where: 'id = ? AND deleted = 0',
      whereArgs: [repairId],
    );
    if (oldRepairs.isEmpty) throw Exception('الإصلاح غير موجود');

    final oldRepair = oldRepairs.first;
    final amount = (oldRepair['amount'] as num?)?.toDouble() ?? 0;
    final treasuryId = oldRepair['treasury_transaction_id'] as String?;

    await db.transaction((txn) async {
      // إلغاء الإصلاح
      await txn.update(DBConstants.tableRepairs, {
        'deleted': 1,
        'status': DBConstants.statusCancelled,
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [repairId]);

      // إلغاء حركة الخزنة
      if (treasuryId != null) {
        await txn.update(DBConstants.tableTreasury, {
          'deleted': 1,
          'status': DBConstants.statusCancelled,
          'updated_at': now,
        }, where: 'id = ?', whereArgs: [treasuryId]);
      }

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'الإصلاحات',
        'action': 'إلغاء إصلاح',
        'old_data': 'المبلغ: $amount، النوع: ${oldRepair['repair_type']}',
        'new_data': 'ملغى مع عكس حركة الخزنة',
        'created_at': now,
      });
    });
  }
}
