import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/partner.dart';
import '../../data/models/partner_transaction.dart';
import '../../data/repositories/partner_repository.dart';

class PartnerAccountScreen extends StatefulWidget {
  final Partner partner;
  const PartnerAccountScreen({super.key, required this.partner});

  @override
  State<PartnerAccountScreen> createState() => _PartnerAccountScreenState();
}

class _PartnerAccountScreenState extends State<PartnerAccountScreen> {
  final PartnerRepository _repo = PartnerRepository();
  List<PartnerTransaction> _transactions = [];
  double _totalWithdrawals = 0;
  double _totalExpenses = 0;
  double _totalSalaries = 0;
  double _totalDeposits = 0;
  double _currentMonthBalance = 0;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _transactions = await _repo.getTransactions(widget.partner.id);
    _totalWithdrawals = await _repo.getTotalWithdrawals(widget.partner.id);
    _totalExpenses = await _repo.getTotalExpenses(widget.partner.id);
    _totalSalaries = await _repo.getTotalPaidSalaries(widget.partner.id);
    _totalDeposits = await _repo.getTotalDeposits(widget.partner.id);
    _currentMonthBalance = await _repo.getTotalByMonth(widget.partner.id, _selectedMonth, _selectedYear);
    setState(() => _isLoading = false);
  }

  /// تسجيل حركة مالية عامة
  Future<void> _addTransaction(String type) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسجيل $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ *'), keyboardType: TextInputType.number),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'البيان / التفاصيل')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              await _repo.addTransaction(
                partnerId: widget.partner.id,
                transactionType: type,
                amount: amount,
                description: descCtrl.text,
                createdBy: 'admin',
              );
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == true) _loadData();
  }

  /// تسجيل دفع راتب شهري
  Future<void> _payMonthlySalary() async {
    final amount = widget.partner.monthlySalary;
    if (amount <= 0) {
      _showMessage('لا يوجد راتب شهري محدد لهذا الشريك', success: false);
      return;
    }

    // اختيار حالة الدفع
    final statusCtrl = ValueNotifier<String>('مدفوع بالكامل');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: statusCtrl,
        builder: (ctx, statusValue, _) => AlertDialog(
          title: const Text('دفع الراتب الشهري'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الراتب الشهري: $amount'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: statusValue,
                decoration: const InputDecoration(labelText: 'حالة الدفع'),
                items: const [
                  DropdownMenuItem(value: 'مستحق', child: Text('مستحق')),
                  DropdownMenuItem(value: 'مدفوع جزئياً', child: Text('مدفوع جزئياً')),
                  DropdownMenuItem(value: 'مدفوع بالكامل', child: Text('مدفوع بالكامل')),
                ],
                onChanged: (v) => statusCtrl.value = v!,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                await _repo.addTransaction(
                  partnerId: widget.partner.id,
                  transactionType: 'راتب',
                  amount: amount,
                  description: 'راتب شهر $_selectedMonth/$_selectedYear',
                  createdBy: 'admin',
                  month: _selectedMonth,
                  year: _selectedYear,
                  salaryStatus: statusCtrl.value,
                );
                Navigator.pop(ctx, true);
              },
              child: const Text('تأكيد الدفع'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) _loadData();
  }

  void _showMessage(String message, {bool success = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب: ${widget.partner.name}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // بطاقة معلومات الشريك
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _infoTile('نسبة الملكية', '${widget.partner.ownershipPercent}%', Icons.pie_chart),
                          _infoTile('الراتب الشهري', '${widget.partner.monthlySalary}', Icons.payments),
                          _infoTile('يوم الاستحقاق', '${widget.partner.salaryDueDay}', Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // بطاقات إحصائية
                  Row(
                    children: [
                      _statCard('السحبيات', _totalWithdrawals, AppTheme.errorColor),
                      _statCard('المصاريف', _totalExpenses, AppTheme.warningColor),
                      _statCard('الرواتب', _totalSalaries, AppTheme.primaryColor),
                      _statCard('الإيداعات', _totalDeposits, AppTheme.successColor),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // رصيد الشهر الحالي
                  Card(
                    color: _currentMonthBalance >= 0 ? AppTheme.successColor.withAlpha(15) : AppTheme.errorColor.withAlpha(15),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('رصيد شهر $_selectedMonth/$_selectedYear'),
                          Text(
                            '${_currentMonthBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _currentMonthBalance >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // أزرار العمليات
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionButton('💰 دفع الراتب', AppTheme.primaryColor, _payMonthlySalary),
                      _actionButton('سحب', AppTheme.errorColor, () => _addTransaction('سحب')),
                      _actionButton('براني', AppTheme.warningColor, () => _addTransaction('براني')),
                      _actionButton('مصروف', AppTheme.warningColor, () => _addTransaction('مصروف شخصي')),
                      _actionButton('سلفة', AppTheme.warningColor, () => _addTransaction('سلفة')),
                      _actionButton('إيداع', AppTheme.successColor, () => _addTransaction('إيداع')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // كشف الحركات
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📋 سجل الحركات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_transactions.isEmpty)
                            const Center(child: Text('لا توجد حركات'))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) {
                                final t = _transactions[index];
                                final isDeposit = t.transactionType == 'إيداع';
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isDeposit ? AppTheme.successColor : AppTheme.errorColor,
                                  ),
                                  title: Text(t.transactionType),
                                  subtitle: Text('${t.transactionDate} ${t.transactionTime ?? ''} | شهر: ${t.month}/${t.year}\n${t.description ?? ''}'),
                                  trailing: Text(
                                    '${t.amount}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDeposit ? AppTheme.successColor : AppTheme.errorColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _statCard(String title, double amount, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 4),
              Text(amount.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text(label),
    );
  }
}
