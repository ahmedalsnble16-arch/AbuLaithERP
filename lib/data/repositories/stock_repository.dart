import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class StockRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> getStockWithProductName({String? search}) async {
    final db = await _dbHelper.database;

    String sql = '''
      SELECT s.*, p.name as product_name, p.unit, p.pieces_per_box
      FROM ${DBConstants.tableStock} s
      INNER JOIN ${DBConstants.tableProducts} p ON s.product_id = p.id
      WHERE p.deleted = 0
    ''';

    List<dynamic>? args;
    if (search != null && search.isNotEmpty) {
      sql += ' AND p.name LIKE ?';
      args = ['%$search%'];
    }

    sql += ' ORDER BY p.name ASC';

    return await db.rawQuery(sql, args);
  }

  /// خصم مخزون آمن. يرمي استثناء عند نقص الكمية بدل التصفير الصامت.
  /// مرّر [txn] عند الاستدعاء من داخل معاملة أكبر لضمان الذرّية.
  Future<void> deductStock(String productId, int quantity,
      {DatabaseExecutor? txn}) async {
    if (quantity <= 0) throw Exception('الكمية يجب أن تكون أكبر من صفر');
    final db = txn ?? await _dbHelper.database;

    final stock = await _getStockByProductId(productId, db: db);
    if (stock == null) {
      throw Exception('لا يوجد مخزون لهذا المنتج');
    }
    if (stock['available_quantity'] < quantity) {
      throw Exception(
          'الكمية المطلوبة ($quantity) أكبر من المتاح (${stock['available_quantity']})');
    }

    await db.update(
      DBConstants.tableStock,
      {
        'quantity_pieces': stock['quantity_pieces'] - quantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> addStock(String productId, int quantity,
      {DatabaseExecutor? txn}) async {
    if (quantity <= 0) throw Exception('الكمية يجب أن تكون أكبر من صفر');
    final db = txn ?? await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final stock = await _getStockByProductId(productId, db: db);
    if (stock != null) {
      await db.update(
        DBConstants.tableStock,
        {
          'quantity_pieces': stock['quantity_pieces'] + quantity,
          'updated_at': now,
        },
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    } else {
      await db.insert(DBConstants.tableStock, {
        'id': _uuid.v4(),
        'product_id': productId,
        'quantity_pieces': quantity,
        'reserved_quantity': 0,
        'average_cost': 0,
        'last_update': now,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<Map<String, dynamic>?> _getStockByProductId(String productId,
      {required DatabaseExecutor db}) async {
    final maps = await db.query(
      DBConstants.tableStock,
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    if (maps.isEmpty) return null;
    final qty = maps.first['quantity_pieces'] as int? ?? 0;
    final reserved = maps.first['reserved_quantity'] as int? ?? 0;
    return {
      'quantity_pieces': qty,
      'reserved_quantity': reserved,
      'available_quantity': qty - reserved,
    };
  }
}
