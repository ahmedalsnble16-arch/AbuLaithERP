import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/recipe.dart';

class RecipeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Recipe>> getByProductId(String productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(DBConstants.tableRecipes, where: 'product_id = ?', whereArgs: [productId]);
    return maps.map((m) => Recipe.fromMap(m)).toList();
  }

  Future<void> save(Recipe recipe) async {
    final db = await _dbHelper.database;
    await db.insert(DBConstants.tableRecipes, recipe.toMap()..['id'] = _uuid.v4());
  }
}
