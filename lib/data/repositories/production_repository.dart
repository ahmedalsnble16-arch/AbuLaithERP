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
    if (batch.goodPieces < 0 || batch.expectedPieces < 0) {
      throw Exception('قيم الإنتاج غير صالحة');
    }

    final db = await _dbHelper.database;
    final id = batch.id.isNotEmpty ? batch.id : _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final productionNumber =
        'PROD-${DateTime.now().millisecondsSinceEpoch}-${id.substring(0, 4)}';

    await db.transaction((txn) async {
      final data = batch.toMap()
        ..['id'] = id
        ..['production_number'] = productionNumber
        ..['created_at'] = now
        ..['updated_at'] = now
        ..['status'] = 'معتمدة';

      await txn.insert(DBConstants.tableProductionBatches, data);

      final stockList = await txn.query(
        DBConstants.tableStock,
        where: 'product_id = ?',
        whereArgs: [batch.productId],
      );

      if (stockList.isEmpty) {
        await txn.insert(DBConstants.tableStock, {
          'id': _uuid.v4(),
          'product_id': batch.productId,
          'quantity_pieces': batch.goodPieces,
          'reserved_quantity': 0,
          'average_cost': batch.productionCost,
          'last_update': now,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
        await txn.update(
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

      await txn.insert(DBConstants.tableStockMovements, {
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
      await txn.insert(DBConstants.tableProductionCompare, compare.toMap());

      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': batch.createdBy,
        'module': 'الإنتاج',
        'action': 'تسجيل إنتاج',
        'old_data': null,
        'new_data':
            'دفعة $productionNumber - صالح ${batch.goodPieces} / متوقع ${batch.expectedPieces}',
        'device_id': batch.deviceId,
        'created_at': now,
      });
    });

    return id;
  }

  Future<void> deleteBatch(String batchId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final batchData = await txn.query(
        DBConstants.tableProductionBatches,
        where: 'id = ? AND deleted = 0',
        whereArgs: [batchId],
      );
      if (batchData.isEmpty) {
        throw Exception('الدفعة غير موجودة أو محذوفة مسبقاً');
      }

      final batch = ProductionBatch.fromMap(batchData.first);

      final stockList = await txn.query(
        DBConstants.tableStock,
        where: 'product_id = ?',
        whereArgs: [batch.productId],
      );
      if (stockList.isNotEmpty) {
        final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
        // منع الحذف إذا كانت البضاعة قد صُرفت/بِيعت
        if (currentQty < batch.goodPieces) {
          throw Exception(
              'لا يمكن حذف الدفعة: المخزون الحالي ($currentQty) أقل من إنتاج الدفعة (${batch.goodPieces})، غالباً تم صرف/بيع جزء منها');
        }
        await txn.update(
          DBConstants.tableStock,
          {'quantity_pieces': currentQty - batch.goodPieces, 'updated_at': now},
          where: 'product_id = ?',
          whereArgs: [batch.productId],
        );
      }

      // حركة مخزون عكسية
      await txn.insert(DBConstants.tableStockMovements, {
        'id': _uuid.v4(),
        'product_id': batch.productId,
        'movement_type': 'حذف إنتاج',
        'quantity': -batch.goodPieces,
        'reference_id': batchId,
        'reference_type': 'production_delete',
        'notes': 'حذف دفعة إنتاج',
        'created_at': now,
        'created_by': batch.createdBy,
        'device_id': batch.deviceId,
        'sync_status': 'Pending',
      });

      // حذف سجل المقارنة المرتبط
      await txn.delete(
        DBConstants.tableProductionCompare,
        where: 'batch_id = ?',
        whereArgs: [batchId],
      );

      await txn.update(
        DBConstants.tableProductionBatches,
        {'deleted': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [batchId],
      );

      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': batch.createdBy,
        'module': 'الإنتاج',
        'action': 'حذف إنتاج',
        'old_data': 'دفعة ${batch.productionNumber} - صالح ${batch.goodPieces}',
        'new_data': null,
        'device_id': batch.deviceId,
        'created_at': now,
      });
    });
  }
}
