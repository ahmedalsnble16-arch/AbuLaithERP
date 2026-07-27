import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/customer.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Customer>> getAll({String? search}) async {
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
      DBConstants.tableCustomers,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<String> add(Customer customer) async {
    final db = await _dbHelper.database;
    final id = customer.id.isNotEmpty ? customer.id : _uuid.v4();
    final data = customer.toMap()..['id'] = id;
    await db.insert(DBConstants.tableCustomers, data);
    return id;
  }

  Future<void> update(Customer customer) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableCustomers,
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableCustomers,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
