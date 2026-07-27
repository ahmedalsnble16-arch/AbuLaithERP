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

  Future<String> createLoad({
    required String distributorId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final loadId = _uuid.v4();
    final now = DatabaseHelper.now;

    await db.insert(DBConstants.tableDistributorLoads, {
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
      final stockList = await db.query(DBConstants.tableStock,
          where: 'product_id = ?', whereArgs: [productId]);
      if (stockList.isNotEmpty) {
        final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
        await db.update(DBConstants.tableStock, {
          'quantity_pieces': currentQty - quantity,
          'updated_at': now,
        }, where: 'product_id = ?', whereArgs: [productId]);
      }
      await db.insert(DBConstants.tableStockMovements, {
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

    return loadId;
  }

  Future<List<DistributorLoad>> getOpenLoads(String distributorId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(DBConstants.tableDistributorLoads,
        where: 'distributor_id = ? AND status = ?',
        whereArgs: [distributorId, 'مفتوحة']);
    return maps.map((m) => DistributorLoad.fromMap(m)).toList();
  }

  Future<String> settleDistributor({
    required String distributorId,
    required String loadId,
    required List<Map<String, dynamic>> items,
    required double collectedCash,
  }) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;

    for (var item in items) {
      final productId = item['productId'];
      final sold = item['sold'] as int;
      final returned = item['returned'] as int;
      final damaged = item['damaged'] as int;
      final unitPrice = (item['unitPrice'] as double);
      final totalSold = sold * unitPrice;
      final commission = totalSold * 0.05;
      final net = totalSold - commission;

      await db.insert(DBConstants.tableDistributorReturns, {
        'id': _uuid.v4(),
        'distributor_id': distributorId,
        'load_id': loadId,
        'product_id': productId,
        'sold': sold,
        'returned': returned,
        'damaged': damaged,
        'collected_cash': collectedCash,
        'commission': commission,
        'net_amount': net,
        'settlement_date': DateTime.now().toIso8601String().substring(0, 10),
        'created_at': now,
        'created_by': 'admin',
        'device_id': 'mobile',
        'sync_status': 'Pending',
      });

      if (returned > 0) {
        final stockList = await db.query(DBConstants.tableStock,
            where: 'product_id = ?', whereArgs: [productId]);
        if (stockList.isNotEmpty) {
          final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
          await db.update(DBConstants.tableStock, {
            'quantity_pieces': currentQty + returned,
            'updated_at': now,
          }, where: 'product_id = ?', whereArgs: [productId]);
        }
      }
    }

    await db.update(DBConstants.tableDistributorLoads,
        {'status': 'مغلقة', 'updated_at': now},
        where: 'id = ?', whereArgs: [loadId]);

    await db.insert(DBConstants.tableTreasury, {
      'id': _uuid.v4(),
      'transaction_number': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
      'transaction_type': 'قبض',
      'amount': collectedCash,
      'source_module': 'موزع',
      'source_id': distributorId,
      'note': 'تحصيل من موزع',
      'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
      'status': 'معتمدة',
      'created_at': now,
      'updated_at': now,
      'created_by': 'admin',
      'device_id': 'mobile',
      'sync_status': 'Pending',
    });

    return loadId;
  }
}
