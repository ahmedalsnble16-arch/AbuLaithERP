import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class PurchaseItemRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getByPurchaseId(String purchaseId) async {
    final db = await _dbHelper.database;
    return await db.query(
      DBConstants.tablePurchaseItems,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  Future<void> add(Map<String, dynamic> item) async {
    final db = await _dbHelper.database;
    await db.insert(DBConstants.tablePurchaseItems, item..['id'] = const Uuid().v4());
  }
}
