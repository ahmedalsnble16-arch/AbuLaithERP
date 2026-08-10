import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/distributor_load_return.dart';

class DistributorReturnRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<void> recordReturn({
    required String distributorId,
    String? loadId,
    required List<Map<String, dynamic>> returnItems,
    String? createdBy,
    String? deviceId,
    DatabaseExecutor? externalTxn,
  }) async {
    final now = DatabaseHelper.now;
    final user = createdBy ?? 'admin';
    final device = deviceId ?? 'mobile';

    String distributorName = '';
    try {
      final distRes = await _dbHelper.database.query(
        DBConstants.tableDistributors,
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [distributorId],
      );
      if (distRes.isNotEmpty) {
        distributorName = distRes.first['name'] as String? ?? '';
      }
    } catch (_) {}

    Future<void> execute(DatabaseExecutor txn) async {
      for (var item in returnItems) {
        final productId = item['productId'] as String;
        final boxes = item['boxes'] as int;
        final pieces = item['pieces'] as int;
        final boxSize = item['boxSize'] as int;
        final totalPieces = (boxes * boxSize) + pieces;
        final unitPrice = (item['unitPrice'] as num).toDouble();
        final totalValue = totalPieces * unitPrice;

        if (totalPieces > 0) {
          await txn.insert(DBConstants.tableDistributorLoadReturns, {
            'id': _uuid.v4(),
            'distributor_id': distributorId,
            'load_id': loadId,
            'product_id': productId,
            'boxes': boxes,
            'pieces': pieces,
            'total_pieces': totalPieces,
            'unit_price': unitPrice,
            'total_value': totalValue,
            'return_date': DateTime.now().toIso8601String().substring(0, 10),
            'created_at': now,
            'created_by': user,
            'device_id': device,
            'sync_status': 'Pending',
          });

          final stockList = await txn.query(DBConstants.tableStock,
              where: 'product_id = ?', whereArgs: [productId]);
          int beforeQty = 0;
          if (stockList.isNotEmpty) {
            beforeQty = stockList.first['quantity_pieces'] as int? ?? 0;
            await txn.update(DBConstants.tableStock, {
              'quantity_pieces': beforeQty + totalPieces,
              'updated_at': now,
            }, where: 'product_id = ?', whereArgs: [productId]);
          } else {
            await txn.insert(DBConstants.tableStock, {
              'id': _uuid.v4(),
              'product_id': productId,
              'quantity_pieces': totalPieces,
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
            'quantity': totalPieces,
            'before_qty': beforeQty,
            'after_qty': beforeQty + totalPieces,
            'reference_id': loadId ?? distributorId,
            'reference_type': 'distributor',
            'distributor_id': distributorId,
            'notes': 'مرتجع من الموزع: $distributorName',
            'created_at': now,
            'created_by': user,
            'device_id': device,
            'sync_status': 'Pending',
          });
        }
      }
    }

    if (externalTxn != null) {
      await execute(externalTxn);
    } else {
      final db = await _dbHelper.database;
      await db.transaction((txn) => execute(txn));
    }
  }

  Future<List<DistributorLoadReturn>> getReturnsForLoad(String loadId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableDistributorLoadReturns,
      where: 'load_id = ?',
      whereArgs: [loadId],
    );
    return maps.map((m) => DistributorLoadReturn.fromMap(m)).toList();
  }

  Future<double> getTotalReturnValue({
    required String distributorId,
    String? loadId,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await _dbHelper.database;
    String where = 'distributor_id = ?';
    List<dynamic> args = [distributorId];
    if (loadId != null) {
      where += ' AND load_id = ?';
      args.add(loadId);
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_value), 0) as total FROM ${DBConstants.tableDistributorLoadReturns} WHERE $where',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
