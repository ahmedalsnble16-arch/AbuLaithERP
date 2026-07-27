import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  Future<List<Expense>> getAll({String? dateFilter}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;

    if (dateFilter != null) {
      where = 'expense_date = ? AND deleted = 0';
      whereArgs = [dateFilter];
    } else {
      where = 'deleted = 0';
    }

    final maps = await db.query(
      DBConstants.tableExpenses,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<String> add(Expense expense) async {
    final db = await _dbHelper.database;
    final id = expense.id.isNotEmpty ? expense.id : _uuid.v4();
    await db.insert(DBConstants.tableExpenses, {
      ...expense.toMap(),
      'id': id,
    });
    return id;
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableExpenses,
      {'deleted': 1, 'updated_at': DatabaseHelper.now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTodayTotal() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableExpenses}
      WHERE expense_date = ? AND deleted = 0
    ''', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
