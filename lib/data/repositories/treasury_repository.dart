import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/treasury.dart';

class TreasuryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  /// جلب جميع الحركات مع الفلاتر
  Future<List<Treasury>> getAll({
    String? dateFilter,
    String? typeFilter,
    String? sourceModuleFilter,
  }) async {
    final db = await _dbHelper.database;
    String where = 'deleted = 0';
    List<dynamic> args = [];

    if (dateFilter != null) {
      where += ' AND transaction_date = ?';
      args.add(dateFilter);
    }
    if (typeFilter != null) {
      where += ' AND transaction_type = ?';
      args.add(typeFilter);
    }
    if (sourceModuleFilter != null) {
      where += ' AND source_module = ?';
      args.add(sourceModuleFilter);
    }

    final maps = await db.query(
      DBConstants.tableTreasury,
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Treasury.fromMap(map)).toList();
  }

  /// إضافة حركة مالية
  Future<String> addTransaction(Treasury transaction, {DatabaseExecutor? txn}) async {
    final db = txn ?? await _dbHelper.database;
    final id = transaction.id.isNotEmpty ? transaction.id : _uuid.v4();
    final transactionNumber = 'TXN-${DateTime.now().millisecondsSinceEpoch}-${id.substring(0, 4)}';

    if (transaction.amount <= 0) {
      throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    }

    await db.insert(DBConstants.tableTreasury, {
      ...transaction.toMap(),
      'id': id,
      'transaction_number': transactionNumber,
    });

    await db.insert(DBConstants.tableAuditLogs, {
      'id': _uuid.v4(),
      'user_id': transaction.createdBy,
      'module': 'الخزنة',
      'action': transaction.transactionType == 'قبض' ? 'سند قبض' : 'سند صرف',
      'new_data': '${transaction.transactionType} ${transaction.amount} - ${transaction.note ?? ''}',
      'device_id': transaction.deviceId,
      'created_at': DateTime.now().toIso8601String(),
    });

    return id;
  }

  /// قبض سريع
  Future<String> addReceipt({
    required double amount,
    String? sourceModule,
    String? sourceId,
    String? note,
    String? createdBy,
    String? deviceId,
    DatabaseExecutor? txn,
  }) async {
    final now = DatabaseHelper.now;
    final transaction = Treasury(
      id: _uuid.v4(),
      transactionNumber: '',
      transactionType: 'قبض',
      amount: amount,
      sourceModule: sourceModule,
      sourceId: sourceId,
      note: note,
      transactionDate: DateTime.now().toIso8601String().substring(0, 10),
      status: 'معتمدة',
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      deviceId: deviceId ?? 'mobile',
    );
    return await addTransaction(transaction, txn: txn);
  }

  /// صرف سريع
  Future<String> addPayment({
    required double amount,
    String? sourceModule,
    String? sourceId,
    String? note,
    String? createdBy,
    String? deviceId,
    DatabaseExecutor? txn,
  }) async {
    final now = DatabaseHelper.now;
    final transaction = Treasury(
      id: _uuid.v4(),
      transactionNumber: '',
      transactionType: 'صرف',
      amount: amount,
      sourceModule: sourceModule,
      sourceId: sourceId,
      note: note,
      transactionDate: DateTime.now().toIso8601String().substring(0, 10),
      status: 'معتمدة',
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      deviceId: deviceId ?? 'mobile',
    );
    return await addTransaction(transaction, txn: txn);
  }

  /// الرصيد الحالي
  Future<double> getCurrentBalance() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN transaction_type = 'قبض' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN transaction_type = 'صرف' THEN amount ELSE 0 END), 0) as balance
      FROM ${DBConstants.tableTreasury}
      WHERE deleted = 0 AND status = 'معتمدة'
    ''');
    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// إجمالي المقبوضات اليوم
  Future<double> getTodayReceipts() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableTreasury}
      WHERE transaction_type = 'قبض' AND transaction_date = ? AND deleted = 0
    ''', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// إجمالي المدفوعات اليوم
  Future<double> getTodayPayments() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableTreasury}
      WHERE transaction_type = 'صرف' AND transaction_date = ? AND deleted = 0
    ''', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// رصيد بداية اليوم
  Future<double> getOpeningBalance() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN transaction_type = 'قبض' THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN transaction_type = 'صرف' THEN amount ELSE 0 END), 0) as balance
      FROM ${DBConstants.tableTreasury}
      WHERE transaction_date < ? AND deleted = 0 AND status = 'معتمدة'
    ''', [today]);
    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// جلب إجمالي المقبوضات حسب المصدر
  Future<double> getTotalReceiptsBySource(String sourceModule) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableTreasury}
      WHERE transaction_type = 'قبض' AND source_module = ? AND deleted = 0
    ''', [sourceModule]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// جلب إجمالي المدفوعات حسب المصدر
  Future<double> getTotalPaymentsBySource(String sourceModule) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableTreasury}
      WHERE transaction_type = 'صرف' AND source_module = ? AND deleted = 0
    ''', [sourceModule]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
