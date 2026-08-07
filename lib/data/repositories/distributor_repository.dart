import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/distributor.dart';
import '../models/distributor_load.dart';

class DistributorRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Distributor>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableDistributors,
      where: 'deleted = 0',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Distributor.fromMap(m)).toList();
  }

  Future<Distributor?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableDistributors,
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Distributor.fromMap(maps.first);
  }

  Future<String> addDistributor(Distributor d) async {
    final db = await _dbHelper.database;
    final id = d.id.isNotEmpty ? d.id : _uuid.v4();
    await db.insert(DBConstants.tableDistributors, {...d.toMap(), 'id': id});
    return id;
  }

  Future<void> updateDistributor(Distributor d) async {
    final db = await _dbHelper.database;
    await db.update(DBConstants.tableDistributors, d.toMap(),
        where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> deleteDistributor(String id) async {
    final db = await _dbHelper.database;
    await db.update(DBConstants.tableDistributors,
        {'deleted': 1, 'updated_at': DatabaseHelper.now},
        where: 'id = ?', whereArgs: [id]);
  }

  /// إنشاء حملة جديدة مع بنودها
  Future<String> createLoad({
    required String distributorId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final loadId = _uuid.v4();
    final now = DatabaseHelper.now;

    await db.transaction((txn) async {
      await txn.insert(DBConstants.tableDistributorLoads, {
        'id': loadId,
        'distributor_id': distributorId,
        'load_date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'مفتوحة',
        'notes': notes,
        'created_at': now,
        'updated_at': now,
        'created_by': 'admin',
        'device_id': 'mobile',
        'sync_status': 'Pending',
      });

      for (var item in items) {
        final productId = item['productId'];
        final quantity = item['quantity'] as int;
        final unitPrice = (item['unitPrice'] as double?) ?? 0;

        // إدراج بند التحميل
        await txn.insert(DBConstants.tableDistributorLoadItems, {
          'id': _uuid.v4(),
          'load_id': loadId,
          'product_id': productId,
          'quantity': quantity,
          'unit_price': unitPrice,
          'created_at': now,
        });

        // خصم المخزون
        final stockList = await txn.query(DBConstants.tableStock,
            where: 'product_id = ?', whereArgs: [productId]);
        if (stockList.isNotEmpty) {
          final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
          await txn.update(DBConstants.tableStock, {
            'quantity_pieces': currentQty - quantity,
            'updated_at': now,
          }, where: 'product_id = ?', whereArgs: [productId]);
        }

        // حركة مخزون
        await txn.insert(DBConstants.tableStockMovements, {
          'id': _uuid.v4(),
          'product_id': productId,
          'movement_type': 'تحميل موزع',
          'quantity': -quantity,
          'reference_id': loadId,
          'reference_type': 'distributor_load',
          'notes': 'تحميل موزع',
          'created_at': now,
          'created_by': 'admin',
          'device_id': 'mobile',
          'sync_status': 'Pending',
        });
      }
    });

    return loadId;
  }

  /// جلب الحملات المفتوحة للموزع
  Future<List<DistributorLoad>> getOpenLoads(String distributorId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(DBConstants.tableDistributorLoads,
        where: 'distributor_id = ? AND status = ?',
        whereArgs: [distributorId, 'مفتوحة']);
    return maps.map((m) => DistributorLoad.fromMap(m)).toList();
  }

  /// جلب جميع الحملات لموزع معين (للأرشيف)
  Future<List<Map<String, dynamic>>> getAllLoads(String distributorId) async {
    final db = await _dbHelper.database;
    return await db.query(
      DBConstants.tableDistributorLoads,
      where: 'distributor_id = ?',
      whereArgs: [distributorId],
      orderBy: 'created_at DESC',
    );
  }

  /// جلب بنود حملة محددة
  Future<List<Map<String, dynamic>>> getLoadItems(String loadId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT dli.*, p.name as product_name, p.pieces_per_box
      FROM ${DBConstants.tableDistributorLoadItems} dli
      JOIN ${DBConstants.tableProducts} p ON dli.product_id = p.id
      WHERE dli.load_id = ?
    ''', [loadId]);
  }

  /// حساب الرصيد السابق (آخر رصيد نهائي من حملة سابقة)
  Future<double> getPreviousBalance(String distributorId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      DBConstants.tableDistributorLoads,
      where: 'distributor_id = ? AND status = ?',
      whereArgs: [distributorId, 'مغلقة'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (result.isEmpty) return 0.0;
    // نقرأ الرصيد النهائي من ملاحظات الحملة أو من حقل مخصص
    // حالياً سنستخدم currentBalance من الموزع نفسه
    final dist = await getById(distributorId);
    return dist?.currentBalance ?? 0.0;
  }

  /// تصفية وإغلاق حملة
  Future<void> settleDistributor({
    required String distributorId,
    required String loadId,
    required double collectedCash,
    required double totalLoadValue,
    required double totalReturnedValue,
    required double totalDamagedValue,
    required double commissionPercent,
  }) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;

    final commission = totalLoadValue * (commissionPercent / 100);
    final netAmount = totalLoadValue - commission - totalReturnedValue - totalDamagedValue - collectedCash;

    // تحديث حالة الحملة إلى مغلقة مع تخزين النتيجة
    await db.update(
      DBConstants.tableDistributorLoads,
      {
        'status': 'مغلقة',
        'updated_at': now,
        'notes': 'إجمالي: $totalLoadValue, خصم: $commission, نقد: $collectedCash, مرتجع: $totalReturnedValue, تالف: $totalDamagedValue, صافي: $netAmount',
      },
      where: 'id = ?',
      whereArgs: [loadId],
    );

    // تحديث رصيد الموزع الحالي
    final dist = await getById(distributorId);
    if (dist != null) {
      final newBalance = netAmount;
      await db.update(
        DBConstants.tableDistributors,
        {'current_balance': newBalance, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [distributorId],
      );
    }

    // قيد في الخزنة
    if (collectedCash > 0) {
      await db.insert(DBConstants.tableTreasury, {
        'id': _uuid.v4(),
        'transaction_number': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        'transaction_type': 'قبض',
        'amount': collectedCash,
        'source_module': 'موزع',
        'source_id': distributorId,
        'note': 'تحصيل من موزع - حملة $loadId',
        'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'معتمدة',
        'created_at': now,
        'updated_at': now,
        'created_by': 'admin',
        'device_id': 'mobile',
        'sync_status': 'Pending',
      });
    }
  }

  /// جلب ملخص كشف الحساب (لرأس الكشف)
  Future<Map<String, dynamic>> getAccountSummary(String distributorId) async {
    final db = await _dbHelper.database;

    // عدد الحملات
    final loadCountResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DBConstants.tableDistributorLoads} WHERE distributor_id = ?',
      [distributorId],
    );
    final loadCount = (loadCountResult.first['count'] as num?)?.toInt() ?? 0;

    // إجمالي المبيعات (قيمة التحميلات) - مجموع الكميات * الأسعار من بنود التحميل
    final salesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(dli.quantity * dli.unit_price), 0) as total
      FROM ${DBConstants.tableDistributorLoadItems} dli
      JOIN ${DBConstants.tableDistributorLoads} dl ON dli.load_id = dl.id
      WHERE dl.distributor_id = ?
    ''', [distributorId]);
    final totalSales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // إجمالي النقد المدفوع (من الخزنة)
    final cashResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableTreasury}
      WHERE source_module = 'موزع' AND source_id = ?
    ''', [distributorId]);
    final totalCash = (cashResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // إجمالي المرتجع
    final returnResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_value), 0) as total
      FROM ${DBConstants.tableDistributorLoadReturns}
      WHERE distributor_id = ?
    ''', [distributorId]);
    final totalReturned = (returnResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // إجمالي التالف
    final damageResult = await db.rawQuery('''
      SELECT COALESCE(SUM(total_value), 0) as total
      FROM ${DBConstants.tableDistributorLoadDamage}
      WHERE distributor_id = ?
    ''', [distributorId]);
    final totalDamaged = (damageResult.first['total'] as num?)?.toDouble() ?? 0.0;

    // إجمالي الخصومات (نسبة العمولة من إجمالي المبيعات)
    final dist = await getById(distributorId);
    final commissionPercent = dist?.commissionPercent ?? 0;
    final totalCommission = totalSales * (commissionPercent / 100);

    // الرصيد الحالي
    final currentBalance = dist?.currentBalance ?? 0.0;

    // آخر حملة
    final lastLoadResult = await db.query(
      DBConstants.tableDistributorLoads,
      where: 'distributor_id = ?',
      whereArgs: [distributorId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    String? lastLoadDate;
    if (lastLoadResult.isNotEmpty) {
      lastLoadDate = lastLoadResult.first['load_date'] as String?;
    }

    return {
      'loadCount': loadCount,
      'totalSales': totalSales,
      'totalCash': totalCash,
      'totalReturned': totalReturned,
      'totalDamaged': totalDamaged,
      'totalCommission': totalCommission,
      'currentBalance': currentBalance,
      'commissionPercent': commissionPercent,
      'lastLoadDate': lastLoadDate,
    };
  }
}
