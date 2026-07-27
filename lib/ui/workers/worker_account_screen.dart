import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class WorkerAccountScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  const WorkerAccountScreen({super.key, required this.workerId, required this.workerName});

  @override
  State<WorkerAccountScreen> createState() => _WorkerAccountScreenState();
}

class _WorkerAccountScreenState extends State<WorkerAccountScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final data = await db.query(DBConstants.tableWorkerAccounts, where: 'worker_id = ?', whereArgs: [widget.workerId], orderBy: 'transaction_date DESC');
    setState(() { _transactions = data; _isLoading = false; });
  }

  Future<void> _addTransaction(String type) async {
    final amountController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة $type'),
        content: TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                final db = await DatabaseHelper().database;
                await db.insert(DBConstants.tableWorkerAccounts, {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'worker_id': widget.workerId,
                  'transaction_type': type,
                  'amount': amount,
                  'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
                  'created_at': DateTime.now().toIso8601String(),
                });
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('حساب: ${widget.workerName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  ElevatedButton.icon(onPressed: () => _addTransaction('سلفة'), icon: const Icon(Icons.money), label: const Text('سلفة')),
                  ElevatedButton.icon(onPressed: () => _addTransaction('برانية'), icon: const Icon(Icons.money_off), label: const Text('برانية')),
                  ElevatedButton.icon(onPressed: () => _addTransaction('مستحق'), icon: const Icon(Icons.credit_card), label: const Text('مستحق')),
                ]),
                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(child: Text('لا توجد حركات'))
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final t = _transactions[index];
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.money, color: Colors.white)),
                              title: Text(t['transaction_type'] ?? ''),
                              subtitle: Text(t['transaction_date'] ?? ''),
                              trailing: Text('${t['amount']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
