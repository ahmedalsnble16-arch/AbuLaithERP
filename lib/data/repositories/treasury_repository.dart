import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/treasury.dart';

class TreasuryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Treasury>> getAll({String? dateFilter}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;
    if (dateFilter != null) {
      where = 'transaction_date = ? AND deleted = 0';
      whereArgs = [dateFilter];
    } else {
      where = 'deleted = 0';
    }
    final maps = await db.query(DBConstants.tableTreasury, where: where, whereArgs: whereArgs, orderBy: 'created_at DESC');
    return maps.map((m) => Treasury.fromMap(m)).toList();
  }

  Future<String> addTransaction(Treasury transaction, {DatabaseExecutor? txn}) async {
    final db = txn ?? await _dbHelper.database;
    final id = transaction.id.isNotEmpty ? transaction.id : _uuid.v4();
    final tn = 'TXN-${DateTime.now().millisecondsSinceEpoch}-${id.substring(0, 4)}';
    if (transaction.amount <= 0) throw Exception('المبلغ يجب أن يكون > 0');
    await db.insert(DBConstants.tableTreasury, {
      ...transaction.toMap(),
      'id': id,
      'transaction_number': tn,
    });
    await db.insert(DBConstants.tableAuditLogs, {
      'id': _uuid.v4(),
      'user_id': transaction.createdBy,
      'module': 'الخزنة',
      'action': transaction.transactionType == 'قبض' ? 'سند قبض' : 'سند صرف',
      'new_data': '${transaction.transactionType} ${transaction.amount} - ${transaction.note ?? ""}',
      'device_id': transaction.deviceId,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<String> addReceipt({required double amount, String? sourceModule, String? sourceId, String? note, String? createdBy}) async {
    final now = DatabaseHelper.now;
    final t = Treasury(id: _uuid.v4(), transactionNumber: '', transactionType: 'قبض', amount: amount, sourceModule: sourceModule, sourceId: sourceId, note: note, transactionDate: DateTime.now().toIso8601String().substring(0,10), status: 'معتمدة', createdAt: now, updatedAt: now, createdBy: createdBy, deviceId: 'mobile');
    return await addTransaction(t);
  }

  Future<String> addPayment({required double amount, String? sourceModule, String? sourceId, String? note, String? createdBy}) async {
    final now = DatabaseHelper.now;
    final t = Treasury(id: _uuid.v4(), transactionNumber: '', transactionType: 'صرف', amount: amount, sourceModule: sourceModule, sourceId: sourceId, note: note, transactionDate: DateTime.now().toIso8601String().substring(0,10), status: 'معتمدة', createdAt: now, updatedAt: now, createdBy: createdBy, deviceId: 'mobile');
    return await addTransaction(t);
  }

  Future<double> getCurrentBalance() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery("SELECT COALESCE(SUM(CASE WHEN transaction_type='قبض' THEN amount ELSE 0 END),0)-COALESCE(SUM(CASE WHEN transaction_type='صرف' THEN amount ELSE 0 END),0) AS balance FROM ${DBConstants.tableTreasury} WHERE deleted=0 AND status='معتمدة'");
    return (res.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTodayReceipts() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0,10);
    final res = await db.rawQuery("SELECT COALESCE(SUM(amount),0) AS total FROM ${DBConstants.tableTreasury} WHERE transaction_type='قبض' AND transaction_date=? AND deleted=0", [today]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTodayPayments() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0,10);
    final res = await db.rawQuery("SELECT COALESCE(SUM(amount),0) AS total FROM ${DBConstants.tableTreasury} WHERE transaction_type='صرف' AND transaction_date=? AND deleted=0", [today]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
