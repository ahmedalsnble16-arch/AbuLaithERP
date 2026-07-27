import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ReportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> getProductionReport({String? dateFrom, String? dateTo}) async {
    final db = await _dbHelper.database;
    String where = 'deleted = 0';
    List<dynamic>? args;
    if (dateFrom != null && dateTo != null) {
      where += ' AND production_date BETWEEN ? AND ?';
      args = [dateFrom, dateTo];
    }
    return await db.query(
      DBConstants.tableProductionBatches,
      where: where,
      whereArgs: args,
      orderBy: 'production_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSalesReport({String? dateFrom, String? dateTo}) async {
    final db = await _dbHelper.database;
    String where = 'deleted = 0';
    List<dynamic>? args;
    if (dateFrom != null && dateTo != null) {
      where += ' AND sale_date BETWEEN ? AND ?';
      args = [dateFrom, dateTo];
    }
    return await db.query(
      DBConstants.tableSales,
      where: where,
      whereArgs: args,
      orderBy: 'sale_date DESC',
    );
  }

  Future<Map<String, dynamic>> getDailySummary() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final production = await db.rawQuery('''
      SELECT COALESCE(SUM(good_pieces), 0) as total
      FROM ${DBConstants.tableProductionBatches}
      WHERE production_date = ? AND deleted = 0
    ''', [today]);

    final sales = await db.rawQuery('''
      SELECT COALESCE(SUM(grand_total), 0) as total
      FROM ${DBConstants.tableSales}
      WHERE sale_date = ? AND deleted = 0
    ''', [today]);

    final expenses = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableExpenses}
      WHERE expense_date = ? AND deleted = 0
    ''', [today]);

    return {
      'production': (production.first['total'] as num?)?.toDouble() ?? 0.0,
      'sales': (sales.first['total'] as num?)?.toDouble() ?? 0.0,
      'expenses': (expenses.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
