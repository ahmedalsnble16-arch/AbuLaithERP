import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/showroom_daily_entry.dart';

class ShowroomRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // الحصول على حركات اليوم لمنتج معين
  Future<ShowroomDailyEntry?> getEntry(String date, String productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'showroom_daily_entries',
      where: 'business_date = ? AND product_id = ?',
      whereArgs: [date, productId],
    );
    if (maps.isEmpty) return null;
    return ShowroomDailyEntry.fromMap(maps.first);
  }

  // حفظ أو تحديث حركة يومية
  Future<void> saveEntry({
    required String businessDate,
    required String productId,
    required int loadBoxes,
    required int loadPieces,
    required int returnBoxes,
    required int returnPieces,
    required int boxSize,
    required double retailPrice,
    String? createdBy,
    String? deviceId,
  }) async {
    final db = await _dbHelper.database;
    final now = DatabaseHelper.now;
    final existing = await getEntry(businessDate, productId);

    final loadTotalPieces = (loadBoxes * boxSize) + loadPieces;
    final returnTotalPieces = (returnBoxes * boxSize) + returnPieces;
    final loadValue = loadTotalPieces * retailPrice;
    final returnValue = returnTotalPieces * retailPrice;
    final netValue = loadValue - returnValue;

    // المدور عليه (البضاعة المتبقية)
    final remainingTotalPieces = loadTotalPieces - returnTotalPieces;
    final remainingBoxes = remainingTotalPieces ~/ boxSize;
    final remainingPieces = remainingTotalPieces % boxSize;
    final remainingValue = remainingTotalPieces * retailPrice;

    await db.transaction((txn) async {
      // 1. خصم السحبيات من مخزن الإنتاج
      if (loadTotalPieces > 0) {
        await _deductFromProductionStock(txn, productId, loadTotalPieces, businessDate, createdBy, deviceId);
      }

      // 2. إرجاع المرتجعات إلى مخزن الإنتاج
      if (returnTotalPieces > 0) {
        await _addToProductionStock(txn, productId, returnTotalPieces, businessDate, createdBy, deviceId);
      }

      // 3. حفظ الحركة اليومية
      if (existing != null) {
        await txn.update(
          'showroom_daily_entries',
          {
            'load_boxes': loadBoxes,
            'load_pieces': loadPieces,
            'load_total_pieces': loadTotalPieces,
            'return_boxes': returnBoxes,
            'return_pieces': returnPieces,
            'return_total_pieces': returnTotalPieces,
            'load_value': loadValue,
            'return_value': returnValue,
            'net_value': netValue,
            'remaining_boxes': remainingBoxes,
            'remaining_pieces': remainingPieces,
            'remaining_value': remainingValue,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
      } else {
        await txn.insert('showroom_daily_entries', {
          'id': _uuid.v4(),
          'business_date': businessDate,
          'product_id': productId,
          'load_boxes': loadBoxes,
          'load_pieces': loadPieces,
          'load_total_pieces': loadTotalPieces,
          'return_boxes': returnBoxes,
          'return_pieces': returnPieces,
          'return_total_pieces': returnTotalPieces,
          'load_value': loadValue,
          'return_value': returnValue,
          'net_value': netValue,
          'remaining_boxes': remainingBoxes,
          'remaining_pieces': remainingPieces,
          'remaining_value': remainingValue,
          'created_at': now,
          'updated_at': now,
        });
      }

      // 4. تدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': createdBy,
        'module': 'المعرض',
        'action': 'تسجيل حركة يومية',
        'new_data': 'سحب $loadTotalPieces قطعة، مرتجع $returnTotalPieces قطعة للمنتج $productId بتاريخ $businessDate',
        'device_id': deviceId,
        'created_at': now,
      });
    });
  }

  // خصم من مخزون الإنتاج
  Future<void> _deductFromProductionStock(DatabaseExecutor txn, String productId, int quantity, String businessDate, String? userId, String? deviceId) async {
    final stockList = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [productId]);
    if (stockList.isEmpty) throw Exception('المنتج غير موجود في مخزن الإنتاج');
    final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
    if (quantity > currentQty) throw Exception('الكمية المطلوبة ($quantity) أكبر من المتاح في مخزن الإنتاج ($currentQty)');
    await txn.update(DBConstants.tableStock, {
      'quantity_pieces': currentQty - quantity,
      'updated_at': DatabaseHelper.now,
    }, where: 'product_id = ?', whereArgs: [productId]);
    await txn.insert(DBConstants.tableStockMovements, {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': 'سحب معرض',
      'quantity': -quantity,
      'before_qty': currentQty,
      'after_qty': currentQty - quantity,
      'reference_id': businessDate,
      'reference_type': 'showroom_load',
      'notes': 'سحب معرض بتاريخ $businessDate',
      'created_at': DatabaseHelper.now,
      'created_by': userId,
      'device_id': deviceId,
      'sync_status': 'Pending',
    });
  }

  // إضافة إلى مخزون الإنتاج (مرتجع)
  Future<void> _addToProductionStock(DatabaseExecutor txn, String productId, int quantity, String businessDate, String? userId, String? deviceId) async {
    final stockList = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [productId]);
    if (stockList.isNotEmpty) {
      final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
      await txn.update(DBConstants.tableStock, {
        'quantity_pieces': currentQty + quantity,
        'updated_at': DatabaseHelper.now,
      }, where: 'product_id = ?', whereArgs: [productId]);
    } else {
      await txn.insert(DBConstants.tableStock, {
        'id': _uuid.v4(),
        'product_id': productId,
        'quantity_pieces': quantity,
        'reserved_quantity': 0,
        'average_cost': 0,
        'last_update': DatabaseHelper.now,
        'created_at': DatabaseHelper.now,
        'updated_at': DatabaseHelper.now,
      });
    }
    await txn.insert(DBConstants.tableStockMovements, {
      'id': _uuid.v4(),
      'product_id': productId,
      'movement_type': 'مرتجع معرض',
      'quantity': quantity,
      'reference_id': businessDate,
      'reference_type': 'showroom_return',
      'notes': 'مرتجع معرض بتاريخ $businessDate',
      'created_at': DatabaseHelper.now,
      'created_by': userId,
      'device_id': deviceId,
      'sync_status': 'Pending',
    });
  }

  // الحصول على جميع حركات اليوم
  Future<List<ShowroomDailyEntry>> getDailyEntries(String businessDate) async {
    final db = await _dbHelper.database;
    final maps = await db.query('showroom_daily_entries', where: 'business_date = ?', whereArgs: [businessDate]);
    return maps.map((m) => ShowroomDailyEntry.fromMap(m)).toList();
  }
}
