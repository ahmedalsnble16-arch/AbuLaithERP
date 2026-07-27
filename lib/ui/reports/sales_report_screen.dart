import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  List<Map<String, dynamic>> _data = [];
  double _totalSales = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('''
      SELECT s.*, si.product_id, si.quantity, si.unit_price, si.total as item_total, p.name as product_name
      FROM ${DBConstants.tableSales} s
      INNER JOIN ${DBConstants.tableSaleItems} si ON s.id = si.sale_id
      INNER JOIN ${DBConstants.tableProducts} p ON si.product_id = p.id
      WHERE s.deleted = 0
      ORDER BY s.sale_date DESC LIMIT 100
    ''');
    double total = 0;
    for (var row in result) { total += (row['grand_total'] as num?)?.toDouble() ?? 0; }
    setState(() { _data = result; _totalSales = total; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير المبيعات')),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(padding: const EdgeInsets.all(16), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Text('عدد الفواتير: ${_data.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('إجمالي المبيعات: $_totalSales', style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
              ])))),
              Expanded(child: ListView.builder(itemCount: _data.length, itemBuilder: (context, index) {
                final row = _data[index];
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.receipt, color: Colors.white)),
                  title: Text(row['product_name'] ?? ''),
                  subtitle: Text('${row['sale_date']} | ${row['payment_type']}'),
                  trailing: Text('${row['item_total']}'),
                );
              })),
            ]),
    );
  }
}
