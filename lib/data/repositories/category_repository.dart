import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Category>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableCategories,
      where: 'deleted = 0',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<String> add(Category category) async {
    final db = await _dbHelper.database;
    final id = category.id.isNotEmpty ? category.id : _uuid.v4();
    final data = category.toMap()..['id'] = id;
    await db.insert(DBConstants.tableCategories, data);
    return id;
  }

  Future<void> update(Category category) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableCategories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableCategories,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
