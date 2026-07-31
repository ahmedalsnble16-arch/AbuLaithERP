import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../models/distributor_product_price.dart';

class DistributorProductPriceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();
  static const String tableName = 'distributor_product_prices';

  Future<void> createTableIfNeeded() async {
    final db = await _dbHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY,
        distributor_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        price REAL NOT NULL,
        UNIQUE(distributor_id, product_id)
      )
    ''');
  }

  Future<Map<String, double>> getPricesForDistributor(String distributorId) async {
    await createTableIfNeeded();
    final db = await _dbHelper.database;
    final maps = await db.query(tableName, where: 'distributor_id = ?', whereArgs: [distributorId]);
    return {for (var m in maps) m['product_id'] as String: (m['price'] as num).toDouble()};
  }

  Future<void> savePrice(String distributorId, String productId, double price) async {
    await createTableIfNeeded();
    final db = await _dbHelper.database;
    await db.insert(
      tableName,
      {
        'id': _uuid.v4(),
        'distributor_id': distributorId,
        'product_id': productId,
        'price': price,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
