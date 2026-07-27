import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/db_constants.dart';
import '../models/production_plan.dart';

class ProductionPlanRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<ProductionPlan>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.query(
      DBConstants.tableProductionPlans,
      where: 'plan_date = ?',
      whereArgs: [date],
    );
    return maps.map((m) => ProductionPlan.fromMap(m)).toList();
  }

  Future<void> add(ProductionPlan plan) async {
    final db = await _db.database;
    await db.insert(
      DBConstants.tableProductionPlans,
      plan.toMap()..['id'] = _uuid.v4(),
    );
  }

  Future<void> update(ProductionPlan plan) async {
    final db = await _db.database;
    await db.update(
      DBConstants.tableProductionPlans,
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      DBConstants.tableProductionPlans,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
