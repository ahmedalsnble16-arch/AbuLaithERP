import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Supplier>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableSuppliers,
      where: 'deleted = 0',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  Future<String> add(Supplier supplier) async {
    final db = await _dbHelper.database;
    final id = supplier.id.isNotEmpty ? supplier.id : _uuid.v4();
    final data = supplier.toMap()..['id'] = id;
    await db.insert(DBConstants.tableSuppliers, data);
    return id;
  }

  Future<void> update(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableSuppliers,
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableSuppliers,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
