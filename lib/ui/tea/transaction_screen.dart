import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _filter = 'الكل';

  @override
  void initState() { super.initState(); _loadTransactions(); }

  Future<void> _loadTransactions() async {
    final db = await DatabaseHelper().database;
    String where = 'deleted = 0';
    if (_filter == 'قبض') where += " AND transaction_type = 'قبض'";
    else if (_filter == 'صرف') where += " AND transaction_type = 'صرف'";
    final maps = await db.query(DBConstants.tableTreasury, where: where, orderBy: 'transaction_date DESC', limit: 200);
    setState(() { _transactions = maps; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المعاملات المالية')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _buildFilterChip('الكل'), _buildFilterChip('قبض'), _buildFilterChip('صرف'),
        ])),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty ? const Center(child: Text('لا توجد معاملات'))
            : ListView.builder(itemCount: _transactions.length, itemBuilder: (context, index) {
                final t = _transactions[index];
                final isReceipt = t['transaction_type'] == 'قبض';
                return ListTile(
                  leading: Icon(isReceipt ? Icons.arrow_downward : Icons.arrow_upward, color: isReceipt ? AppTheme.successColor : AppTheme.errorColor),
                  title: Text(t['note'] ?? 'بدون بيان'),
                  subtitle: Text('${t['transaction_date']}'),
                  trailing: Text('${t['amount']}'),
                );
              })),
      ]),
    );
  }

  Widget _buildFilterChip(String label) {
    return FilterChip(label: Text(label), selected: _filter == label, onSelected: (selected) { setState(() => _filter = label); _loadTransactions(); });
  }
}
