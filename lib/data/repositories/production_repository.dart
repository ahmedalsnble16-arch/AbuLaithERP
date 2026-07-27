import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/production_batch.dart';
import '../models/production_compare.dart';

class ProductionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<ProductionBatch>> getAllBatches({String? search}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;

    if (search != null && search.isNotEmpty) {
      where = 'production_number LIKE ? AND deleted = 0';
      whereArgs = ['%$search%'];
    } else {
      where = 'deleted = 0';
    }

    final maps = await db.query(
      DBConstants.tableProductionBatches,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'production_date DESC',
    );
    return maps.map((map) => ProductionBatch.fromMap(map)).toList();
  }

  Future<String> createBatch(ProductionBatch batch) async {
    final db = await _dbHelper.database;
    final id = batch.id.isNotEmpty ? batch.id : _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final productionNumber = 'PROD-${DateTime.now().millisecondsSinceEpoch}';

    final data = batch.toMap()
      ..['id'] = id
      ..['production_number'] = productionNumber
      ..['created_at'] = now
      ..['updated_at'] = now
      ..['status'] = 'معتمدة';

    await db.insert(DBConstants.tableProductionBatches, data);

    final stockList = await db.query(
      DBConstants.tableStock,
      where: 'product_id = ?',
      whereArgs: [batch.productId],
    );

    if (stockList.isEmpty) {
      await db.insert(DBConstants.tableStock, {
        'id': _uuid.v4(),
        'product_id': batch.productId,
        'quantity_pieces': batch.goodPieces,
        'average_cost': batch.productionCost,
        'last_update': now,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
      await db.update(
        DBConstants.tableStock,
        {
          'quantity_pieces': currentQty + batch.goodPieces,
          'last_update': now,
          'updated_at': now,
        },
        where: 'product_id = ?',
        whereArgs: [batch.productId],
      );
    }

    await db.insert(DBConstants.tableStockMovements, {
      'id': _uuid.v4(),
      'product_id': batch.productId,
      'movement_type': 'إنتاج',
      'quantity': batch.goodPieces,
      'reference_id': id,
      'reference_type': 'production',
      'notes': 'إنتاج دفعة $productionNumber',
      'created_at': now,
      'created_by': batch.createdBy,
      'device_id': batch.deviceId,
      'sync_status': 'Pending',
    });

    final compare = ProductionCompare(
      id: _uuid.v4(),
      productId: batch.productId,
      batchId: id,
      expectedPieces: batch.expectedPieces,
      actualPieces: batch.goodPieces,
      difference: batch.expectedPieces - batch.goodPieces,
      lossPercent: batch.expectedPieces > 0
          ? ((batch.damagedPieces + batch.lostPieces) / batch.expectedPieces) * 100
          : 0,
      notes: batch.notes,
      compareDate: batch.productionDate,
      createdAt: now,
      createdBy: batch.createdBy,
      deviceId: batch.deviceId,
    );
    await db.insert(DBConstants.tableProductionCompare, compare.toMap());

    return id;
  }

  Future<void> deleteBatch(String batchId) async {
    final db = await _dbHelper.database;
    final batchData = await db.query(
      DBConstants.tableProductionBatches,
      where: 'id = ?',
      whereArgs: [batchId],
    );
    if (batchData.isNotEmpty) {
      final batch = ProductionBatch.fromMap(batchData.first);
      final stockList = await db.query(
        DBConstants.tableStock,
        where: 'product_id = ?',
        whereArgs: [batch.productId],
      );
      if (stockList.isNotEmpty) {
        final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
        final newQty = currentQty - batch.goodPieces;
        await db.update(
          DBConstants.tableStock,
          {
            'quantity_pieces': newQty < 0 ? 0 : newQty,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'product_id = ?',
          whereArgs: [batch.productId],
        );
      }
    }

    await db.update(
      DBConstants.tableProductionBatches,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [batchId],
    );
  }
}
