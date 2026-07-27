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
}
