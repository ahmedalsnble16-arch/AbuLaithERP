import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ProductionReportScreen extends StatefulWidget {
  const ProductionReportScreen({super.key});

  @override
  State<ProductionReportScreen> createState() => _ProductionReportScreenState();
}

class _ProductionReportScreenState extends State<ProductionReportScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('''
      SELECT pb.*, p.name as product_name
      FROM ${DBConstants.tableProductionBatches} pb
      INNER JOIN ${DBConstants.tableProducts} p ON pb.product_id = p.id
      WHERE pb.deleted = 0
      ORDER BY pb.production_date DESC
      LIMIT 100
    ''');
    setState(() {
      _data = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير الإنتاج')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('لا توجد بيانات'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('المنتج')),
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('متوقع')),
                      DataColumn(label: Text('صالح')),
                      DataColumn(label: Text('تالف')),
                      DataColumn(label: Text('فاقد')),
                      DataColumn(label: Text('نسبة الهدر')),
                    ],
                    rows: _data.map((row) {
                      final expected = row['expected_pieces'] as int? ?? 0;
                      final damaged = row['damaged_pieces'] as int? ?? 0;
                      final lost = row['lost_pieces'] as int? ?? 0;
                      final lossPercent = expected > 0 ? ((damaged + lost) / expected) * 100 : 0.0;
                      return DataRow(cells: [
                        DataCell(Text(row['product_name'] ?? '')),
                        DataCell(Text(row['production_date'] ?? '')),
                        DataCell(Text('$expected')),
                        DataCell(Text('${row['good_pieces'] ?? 0}')),
                        DataCell(Text('$damaged', style: TextStyle(color: damaged > 0 ? AppTheme.errorColor : null))),
                        DataCell(Text('$lost', style: TextStyle(color: lost > 0 ? AppTheme.warningColor : null))),
                        DataCell(Text('${lossPercent.toStringAsFixed(1)}%', style: TextStyle(color: lossPercent > 5 ? AppTheme.errorColor : AppTheme.successColor))),
                      ]);
                    }).toList(),
                  ),
                ),
    );
  }
}
