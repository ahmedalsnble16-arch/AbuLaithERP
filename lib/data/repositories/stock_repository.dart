import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class StockRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

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

  Future<bool> deductStock(String productId, int quantity) async {
    final db = await _dbHelper.database;
    final stock = await _getStockByProductId(productId);
    if (stock == null || stock['available_quantity'] < quantity) return false;
    
    await db.update(
      DBConstants.tableStock,
      {
        'quantity_pieces': stock['quantity_pieces'] - quantity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return true;
  }

  Future<void> addStock(String productId, int quantity) async {
    final db = await _dbHelper.database;
    final stock = await _getStockByProductId(productId);
    if (stock != null) {
      await db.update(
        DBConstants.tableStock,
        {
          'quantity_pieces': stock['quantity_pieces'] + quantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    } else {
      // إنشاء سجل مخزون جديد إذا لم يكن موجوداً
      await db.insert(
        DBConstants.tableStock,
        {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'product_id': productId,
          'quantity_pieces': quantity,
          'reserved_quantity': 0,
          'average_cost': 0,
          'last_update': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<Map<String, dynamic>?> _getStockByProductId(String productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableStock,
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    if (maps.isEmpty) return null;
    return {
      'quantity_pieces': maps.first['quantity_pieces'] as int? ?? 0,
      'reserved_quantity': maps.first['reserved_quantity'] as int? ?? 0,
      'available_quantity': (maps.first['quantity_pieces'] as int? ?? 0) - (maps.first['reserved_quantity'] as int? ?? 0),
    };
  }
}
