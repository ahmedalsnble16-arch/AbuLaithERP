import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/partner.dart';
import '../models/partner_transaction.dart';

class PartnerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // ========== الشركاء ==========
  Future<List<Partner>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tablePartners,
      where: 'deleted = 0',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Partner.fromMap(m)).toList();
  }

  Future<Partner?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tablePartners,
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Partner.fromMap(maps.first);
  }

  Future<String> add(Partner partner) async {
    final db = await _dbHelper.database;
    final id = partner.id.isNotEmpty ? partner.id : _uuid.v4();
    await db.insert(DBConstants.tablePartners, {...partner.toMap(), 'id': id});
    return id;
  }

  Future<void> update(Partner partner) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tablePartners,
      partner.toMap(),
      where: 'id = ?',
      whereArgs: [partner.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tablePartners,
      {'deleted': 1, 'updated_at': DatabaseHelper.now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== حركات الشريك ==========
  Future<List<PartnerTransaction>> getTransactions(String partnerId, {int? month, int? year}) async {
    final db = await _dbHelper.database;
    String where = 'partner_id = ?';
    List<dynamic> args = [partnerId];

    if (month != null) {
      where += ' AND month = ?';
      args.add(month);
    }
    if (year != null) {
      where += ' AND year = ?';
      args.add(year);
    }

    final maps = await db.query(
      DBConstants.tablePartnerTransactions,
      where: where,
      whereArgs: args,
      orderBy: 'transaction_date DESC, transaction_time DESC',
    );
    return maps.map((m) => PartnerTransaction.fromMap(m)).toList();
  }

  /// تسجيل حركة مالية لشريك مع ترحيل للخزنة
  /// يتم ضبط شهر وسنة الاستحقاق تلقائياً من تاريخ العملية
  Future<String> addTransaction({
    required String partnerId,
    required String transactionType,
    required double amount,
    String? description,
    String? treasuryTransactionId,
    String? createdBy,
    int? month,
    int? year,
    String? salaryStatus,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final id = _uuid.v4();

    // ضبط الشهر والسنة تلقائياً إذا لم يتم تمريرهما
    final autoMonth = month ?? now.month;
    final autoYear = year ?? now.year;

    await db.transaction((txn) async {
      // 1. تسجيل حركة الشريك
      await txn.insert(DBConstants.tablePartnerTransactions, {
        'id': id,
        'partner_id': partnerId,
        'transaction_type': transactionType,
        'amount': amount,
        'description': description,
        'transaction_date': now.toIso8601String().substring(0, 10),
        'transaction_time': now.toIso8601String().substring(11, 19),
        'month': autoMonth,
        'year': autoYear,
        'salary_status': salaryStatus,
        'paid_amount': salaryStatus == 'مدفوع بالكامل' ? amount : 0,
        'remaining_amount': salaryStatus == 'مدفوع بالكامل' ? 0 : amount,
        'treasury_transaction_id': treasuryTransactionId,
        'created_at': now.toIso8601String(),
        'created_by': createdBy,
        'device_id': 'mobile',
        'sync_status': 'Pending',
      });

      // 2. ترحيل للخزنة
      final isDeposit = transactionType == DBConstants.partnerTxnDeposit;
      await txn.insert(DBConstants.tableTreasury, {
        'id': _uuid.v4(),
        'transaction_number': 'TXN-${now.millisecondsSinceEpoch}',
        'transaction_type': isDeposit ? 'قبض' : 'صرف',
        'amount': amount,
        'source_module': 'شريك',
        'source_id': partnerId,
        'note': description ?? transactionType,
        'transaction_date': now.toIso8601String().substring(0, 10),
        'status': 'معتمدة',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'created_by': createdBy,
        'device_id': 'mobile',
        'sync_status': 'Pending',
      });
    });

    return id;
  }

  // ========== الحسابات ==========
  Future<double> getTotalWithdrawals(String partnerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tablePartnerTransactions}
      WHERE partner_id = ? AND transaction_type IN ('سحب', 'براني', 'سلفة')
    ''', [partnerId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalExpenses(String partnerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tablePartnerTransactions}
      WHERE partner_id = ? AND transaction_type = 'مصروف شخصي'
    ''', [partnerId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalPaidSalaries(String partnerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tablePartnerTransactions}
      WHERE partner_id = ? AND transaction_type = 'راتب' AND salary_status = 'مدفوع بالكامل'
    ''', [partnerId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalDeposits(String partnerId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tablePartnerTransactions}
      WHERE partner_id = ? AND transaction_type = 'إيداع'
    ''', [partnerId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// جلب إجمالي حركات شهر محدد
  Future<double> getTotalByMonth(String partnerId, int month, int year) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN transaction_type = 'إيداع' THEN amount ELSE -amount END), 0) as total
      FROM ${DBConstants.tablePartnerTransactions}
      WHERE partner_id = ? AND month = ? AND year = ?
    ''', [partnerId, month, year]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
