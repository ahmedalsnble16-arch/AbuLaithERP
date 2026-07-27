import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/raw_material.dart';

class RawMaterialRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<RawMaterial>> getAll({String? search}) async {
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
      DBConstants.tableRawMaterials,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map((map) => RawMaterial.fromMap(map)).toList();
  }

  Future<String> add(RawMaterial material) async {
    final db = await _dbHelper.database;
    final id = material.id.isNotEmpty ? material.id : _uuid.v4();
    final data = material.toMap()..['id'] = id;
    await db.insert(DBConstants.tableRawMaterials, data);
    return id;
  }

  Future<void> update(RawMaterial material) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableRawMaterials,
      material.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableRawMaterials,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
