import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/repair.dart';

class RepairRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  /// جلب جميع الإصلاحات
  Future<List<Repair>> getAll({String? dateFilter, String? typeFilter}) async {
    final db = await _dbHelper.database;
    String where = 'deleted = 0';
    List<dynamic> args = [];

    if (dateFilter != null) {
      where += ' AND repair_date = ?';
      args.add(dateFilter);
    }
    if (typeFilter != null) {
      where += ' AND repair_type = ?';
      args.add(typeFilter);
    }

    final maps = await db.query(
      'repairs',
      where: where,
      whereArgs: args,
      orderBy: 'repair_date DESC, created_at DESC',
    );
    return maps.map((m) => Repair.fromMap(m)).toList();
  }

  /// جلب أنواع الإصلاحات
  Future<List<String>> getRepairTypes() async {
    final db = await _dbHelper.database;
    final maps = await db.query('repair_types', orderBy: 'name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  /// إضافة إصلاح مع ترحيل للخزنة
  Future<String> addRepair({
    required String repairType,
    required String description,
    required double amount,
    String? notes,
    String? createdBy,
    String? deviceId,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final repairId = _uuid.v4();
    final treasuryId = _uuid.v4();

    await db.transaction((txn) async {
      // 1. تسجيل الإصلاح
      await txn.insert('repairs', {
        'id': repairId,
        'repair_type': repairType,
        'description': description,
        'amount': amount,
        'repair_date': now.toIso8601String().substring(0, 10),
        'repair_time': now.toIso8601String().substring(11, 19),
        'notes': notes,
        'created_by': createdBy,
        'treasury_transaction_id': treasuryId,
        'status': 'معتمدة',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'device_id': deviceId,
        'sync_status': 'Pending',
        'deleted': 0,
      });

      // 2. ترحيل للخزنة (صرف)
      await txn.insert(DBConstants.tableTreasury, {
        'id': treasuryId,
        'transaction_number': 'REP-${now.millisecondsSinceEpoch}',
        'transaction_type': 'صرف',
        'amount': amount,
        'source_module': 'إصلاحات',
        'source_id': repairId,
        'note': '$repairType - $description',
        'transaction_date': now.toIso8601String().substring(0, 10),
        'status': 'معتمدة',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'created_by': createdBy,
        'device_id': deviceId,
        'sync_status': 'Pending',
      });

      // 3. سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': createdBy,
        'module': 'الإصلاحات',
        'action': 'إضافة إصلاح',
        'new_data': '$repairType - $description - $amount ريال',
        'device_id': deviceId,
        'created_at': now.toIso8601String(),
      });
    });

    return repairId;
  }

  /// إجمالي اليوم
  Future<double> getTodayTotal() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM repairs
      WHERE repair_date = ? AND deleted = 0
    ''', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// إجمالي الشهر
  Future<double> getMonthTotal({int? month, int? year}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM repairs
      WHERE strftime('%m', repair_date) = ? AND strftime('%Y', repair_date) = ? AND deleted = 0
    ''', [m.toString().padLeft(2, '0'), '$y']);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// إجمالي السنة
  Future<double> getYearTotal({int? year}) async {
    final db = await _dbHelper.database;
    final y = year ?? DateTime.now().year;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM repairs
      WHERE strftime('%Y', repair_date) = ? AND deleted = 0
    ''', ['$y']);
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// إجمالي كلي
  Future<double> getTotalAll() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM repairs WHERE deleted = 0
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// عدد الإصلاحات
  Future<int> getCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM repairs WHERE deleted = 0');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// تعديل إصلاح مع تصحيح الخزنة
  Future<void> updateRepair({
    required String repairId,
    required String repairType,
    required String description,
    required double newAmount,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final oldRepair = await db.query('repairs', where: 'id = ?', whereArgs: [repairId]);
    if (oldRepair.isEmpty) throw Exception('الإصلاح غير موجود');

    final oldAmount = (oldRepair.first['amount'] as num?)?.toDouble() ?? 0;
    final treasuryId = oldRepair.first['treasury_transaction_id'] as String?;

    await db.transaction((txn) async {
      // تحديث الإصلاح
      await txn.update('repairs', {
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
          'updated_at': now,
        }, where: 'id = ?', whereArgs: [treasuryId]);
      }

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'الإصلاحات',
        'action': 'تعديل إصلاح',
        'old_data': 'المبلغ القديم: $oldAmount',
        'new_data': 'المبلغ الجديد: $newAmount',
        'created_at': now,
      });
    });
  }

  /// إلغاء إصلاح مع عكس حركة الخزنة
  Future<void> cancelRepair(String repairId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final oldRepair = await db.query('repairs', where: 'id = ?', whereArgs: [repairId]);
    if (oldRepair.isEmpty) throw Exception('الإصلاح غير موجود');

    final amount = (oldRepair.first['amount'] as num?)?.toDouble() ?? 0;
    final treasuryId = oldRepair.first['treasury_transaction_id'] as String?;

    await db.transaction((txn) async {
      // إلغاء الإصلاح
      await txn.update('repairs', {
        'deleted': 1,
        'status': 'ملغاة',
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [repairId]);

      // إلغاء حركة الخزنة
      if (treasuryId != null) {
        await txn.update(DBConstants.tableTreasury, {
          'deleted': 1,
          'status': 'ملغاة',
          'updated_at': now,
        }, where: 'id = ?', whereArgs: [treasuryId]);
      }

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'الإصلاحات',
        'action': 'إلغاء إصلاح',
        'old_data': 'المبلغ: $amount',
        'new_data': 'ملغى',
        'created_at': now,
      });
    });
  }
}
