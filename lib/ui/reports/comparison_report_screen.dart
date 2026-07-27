import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ComparisonReportScreen extends StatefulWidget {
  const ComparisonReportScreen({super.key});

  @override
  State<ComparisonReportScreen> createState() => _ComparisonReportScreenState();
}

class _ComparisonReportScreenState extends State<ComparisonReportScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('''
      SELECT pc.*, p.name as product_name
      FROM ${DBConstants.tableProductionCompare} pc
      INNER JOIN ${DBConstants.tableProducts} p ON pc.product_id = p.id
      ORDER BY pc.compare_date DESC
      LIMIT 100
    ''');
    setState(() { _data = result; _isLoading = false; });
  }

  Color _getColor(double lossPercent) {
    if (lossPercent <= 2) return AppTheme.successColor;
    if (lossPercent <= 5) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف المقارنة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('لا توجد بيانات'))
              : ListView.builder(
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    final b = _data[index];
                    final expected = b['expected_pieces'] as int? ?? 0;
                    final actual = b['actual_pieces'] as int? ?? 0;
                    final lossPercent = (b['loss_percent'] as num?)?.toDouble() ?? 0;
                    return Card(
                      color: _getColor(lossPercent).withAlpha(20),
                      child: ListTile(
                        title: Text(b['product_name'] ?? ''),
                        subtitle: Text('المتوقع: $expected | الفعلي: $actual'),
                        trailing: Text('${lossPercent.toStringAsFixed(1)}%', style: TextStyle(color: _getColor(lossPercent), fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}
