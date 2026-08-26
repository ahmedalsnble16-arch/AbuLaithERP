import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/worker.dart';

class WorkerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Worker>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableWorkers,
      where: 'deleted = 0',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Worker.fromMap(map)).toList();
  }

  Future<String> add(Worker worker) async {
    final db = await _dbHelper.database;
    final id = worker.id.isNotEmpty ? worker.id : _uuid.v4();
    final data = worker.toMap()..['id'] = id;
    await db.insert(DBConstants.tableWorkers, data);
    return id;
  }

  Future<void> update(Worker worker) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableWorkers,
      worker.toMap(),
      where: 'id = ?',
      whereArgs: [worker.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableWorkers,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleActive(String id, bool active) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableWorkers,
      {'active': active ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== الحد الأقصى للسحب الشهري ==========

  /// الحصول على الحد الشهري للسحب للعامل
  Future<double> getMonthlyWithdrawalLimit(String workerId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableWorkers,
      columns: ['monthly_withdrawal_limit'],
      where: 'id = ?',
      whereArgs: [workerId],
    );
    if (maps.isEmpty) return 0;
    return (maps.first['monthly_withdrawal_limit'] as num?)?.toDouble() ?? 0;
  }

  /// تحديث الحد الشهري للسحب
  Future<void> updateMonthlyWithdrawalLimit(String workerId, double newLimit) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    await db.update(
      DBConstants.tableWorkers,
      {'monthly_withdrawal_limit': newLimit, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [workerId],
    );

    // تسجيل في Audit Log
    await db.insert(DBConstants.tableAuditLogs, {
      'id': _uuid.v4(),
      'user_id': 'admin',
      'module': 'العمال',
      'action': 'تعديل حد السحب الشهري',
      'new_data': 'الحد الجديد: $newLimit',
      'created_at': now,
    });
  }

  /// حساب إجمالي السحبيات الشهرية للعامل
  Future<double> getMonthlyWithdrawals(String workerId, {int? month, int? year}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableWorkerAccounts}
      WHERE worker_id = ?
        AND transaction_type IN ('برانية', 'سلفة')
        AND strftime('%m', transaction_date) = ?
        AND strftime('%Y', transaction_date) = ?
    ''', [workerId, targetMonth.toString().padLeft(2, '0'), '$targetYear']);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// التحقق من إمكانية السحب (إرجاع رسالة خطأ إذا تجاوز الحد)
  Future<String?> canWithdraw(String workerId, double amount) async {
    final limit = await getMonthlyWithdrawalLimit(workerId);
    if (limit <= 0) return null; // لا يوجد حد محدد

    final withdrawn = await getMonthlyWithdrawals(workerId);
    final remaining = limit - withdrawn;

    if (amount > remaining) {
      return 'لا يمكن تنفيذ السحب لأنه يتجاوز الحد الأقصى الشهري للعامل.\n\n'
          'الحد الأقصى: $limit ريال\n'
          'المسحوب حتى الآن: $withdrawn ريال\n'
          'المبلغ المطلوب: $amount ريال\n'
          'المتبقي المسموح: $remaining ريال';
    }

    return null; // مسموح
  }
}
