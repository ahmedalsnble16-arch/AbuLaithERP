import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/treasury_repository.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final TreasuryRepository _repo = TreasuryRepository();
  double _balance = 0;
  double _todayReceipts = 0;
  double _todayPayments = 0;
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _balance = await _repo.getCurrentBalance();
      _todayReceipts = await _repo.getTodayReceipts();
      _todayPayments = await _repo.getTodayPayments();
      _transactions = await _repo.getAll();
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog({required String type}) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'قبض' ? 'سند قبض' : 'سند صرف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'البيان')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              if (type == 'قبض') {
                await _repo.addReceipt(amount: amount, note: noteController.text);
              } else {
                await _repo.addPayment(amount: amount, note: noteController.text);
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخزنة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      _buildSummaryCard('الرصيد', _balance, AppTheme.primaryColor),
                      _buildSummaryCard('قبض اليوم', _todayReceipts, AppTheme.successColor),
                      _buildSummaryCard('صرف اليوم', _todayPayments, AppTheme.errorColor),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAddDialog(type: 'قبض'),
                      icon: const Icon(Icons.add),
                      label: const Text('قبض'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddDialog(type: 'صرف'),
                      icon: const Icon(Icons.remove),
                      label: const Text('صرف'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('لا توجد حركات'))
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final t = _transactions[index];
                            return ListTile(
                              leading: Icon(
                                t.transactionType == 'قبض' ? Icons.arrow_downward : Icons.arrow_upward,
                                color: t.transactionType == 'قبض' ? AppTheme.successColor : AppTheme.errorColor,
                              ),
                              title: Text(t.note ?? ''),
                              subtitle: Text(t.transactionDate),
                              trailing: Text('${t.amount}'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('$amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
