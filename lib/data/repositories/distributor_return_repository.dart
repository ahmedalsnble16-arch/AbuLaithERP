
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/distributor_load_return.dart';
import 'stock_repository.dart';

class DistributorReturnRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();
  final StockRepository _stockRepo = StockRepository();

  Future<List<DistributorLoadReturn>> getReturnsForLoad(String loadId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableDistributorLoadReturns,
      where: 'load_id = ?',
      whereArgs: [loadId],
    );
    return maps.map((m) => DistributorLoadReturn.fromMap(m)).toList();
  }

  Future<void> recordReturn({
    required String distributorId,
    String? loadId,
    required List<Map<String, dynamic>> returnItems,
    String? createdBy,
    String? deviceId,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await _dbHelper.database;
    final now = DatabaseHelper.now;
    final user = createdBy ?? 'admin';
    final device = deviceId ?? 'mobile';

    for (var item in returnItems) {
      final productId = item['productId'] as String;
      final boxes = item['boxes'] as int;
      final pieces = item['pieces'] as int;
      final boxSize = item['boxSize'] as int;
      final totalPieces = (boxes * boxSize) + pieces;
      final unitPrice = (item['unitPrice'] as num).toDouble();
      final totalValue = totalPieces * unitPrice;

      if (totalPieces > 0) {
        await db.insert(DBConstants.tableDistributorLoadReturns, {
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

        // إرجاع المنتج إلى مخزون الإنتاج
        await _stockRepo.addStock(productId, totalPieces, txn: db);

        // حركة مخزون
        await db.insert(DBConstants.tableStockMovements, {
          'id': _uuid.v4(),
          'product_id': productId,
          'movement_type': 'مرتجع موزع',
          'quantity': totalPieces,
          'reference_id': loadId ?? distributorId,
          'reference_type': 'distributor_return',
          'notes': 'مرتجع من موزع',
          'created_at': now,
          'created_by': user,
          'device_id': device,
          'sync_status': 'Pending',
        });
      }
    }
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
