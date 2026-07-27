import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/treasury_repository.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final TreasuryRepository _treasuryRepo = TreasuryRepository();
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      _expenses = await _expenseRepo.getAll();
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مصروف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'العنوان')),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'الفئة')),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              final now = DatabaseHelper.now;
              final expense = Expense(
                id: const Uuid().v4(),
                title: titleController.text,
                category: categoryController.text,
                amount: amount,
                note: noteController.text,
                expenseDate: DateTime.now().toIso8601String().substring(0, 10),
                createdAt: now,
                updatedAt: now,
                createdBy: 'admin',
                deviceId: 'mobile',
              );
              await _expenseRepo.add(expense);
              await _treasuryRepo.addPayment(amount: amount, sourceModule: 'مصروف', note: titleController.text);
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(child: Text('لا توجد مصروفات'))
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final expense = _expenses[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.warningColor,
                        child: Icon(Icons.money_off, color: Colors.white),
                      ),
                      title: Text(expense.title),
                      subtitle: Text('${expense.expenseDate} | ${expense.category ?? ""}'),
                      trailing: Text('${expense.amount}', style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
    );
  }
}
