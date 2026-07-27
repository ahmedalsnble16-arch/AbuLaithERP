import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/treasury_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/sale_repository.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  double _balance = 0;
  double _todaySales = 0;
  double _todayExpenses = 0;
  double _todayReceipts = 0;
  double _todayPayments = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final treasuryRepo = TreasuryRepository();
    final expenseRepo = ExpenseRepository();
    final saleRepo = SaleRepository();

    _balance = await treasuryRepo.getCurrentBalance();
    _todayReceipts = await treasuryRepo.getTodayReceipts();
    _todayPayments = await treasuryRepo.getTodayPayments();
    _todayExpenses = await expenseRepo.getTodayTotal();

    final sales = await saleRepo.getTodaySales();
    _todaySales = sales.fold(0, (sum, s) => sum + s.grandTotal);

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final profit = _todaySales - _todayExpenses - _todayPayments;
    return Scaffold(
      appBar: AppBar(title: const Text('التقرير المالي')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCard('رصيد الخزنة', _balance, AppTheme.primaryColor),
                _buildCard('مبيعات اليوم', _todaySales, Colors.teal),
                _buildCard('قبض اليوم', _todayReceipts, AppTheme.successColor),
                _buildCard('صرف اليوم', _todayPayments, AppTheme.errorColor),
                _buildCard('مصروفات اليوم', _todayExpenses, AppTheme.warningColor),
                const Divider(),
                _buildCard('صافي الربح', profit, profit >= 0 ? AppTheme.successColor : AppTheme.errorColor),
              ],
            ),
    );
  }

  Widget _buildCard(String title, double amount, Color color) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text('$amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
