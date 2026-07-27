import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/product.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Product>> getAll({String? search}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;

    if (search != null && search.isNotEmpty) {
      where = 'name LIKE ? AND deleted = 0';
      whereArgs = ['%$search%'];
    } else {
      where = 'deleted = 0';
    }

    final maps = await db.query(
      DBConstants.tableProducts,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<String> add(Product product) async {
    final db = await _dbHelper.database;
    final id = product.id.isNotEmpty ? product.id : _uuid.v4();
    final data = product.toMap()..['id'] = id;
    await db.insert(DBConstants.tableProducts, data);
    return id;
  }

  Future<void> update(Product product) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableProducts,
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableProducts,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
