import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class WorkerAccountScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final double dailySalary;
  final double dailyExpense;
  final bool isActive;

  const WorkerAccountScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    this.dailySalary = 0,
    this.dailyExpense = 0,
    this.isActive = true,
  });

  @override
  State<WorkerAccountScreen> createState() => _WorkerAccountScreenState();
}

class _WorkerAccountScreenState extends State<WorkerAccountScreen> {
  String _selectedMonth = DateTime.now().toIso8601String().substring(0, 7);
  List<Map<String, dynamic>> _dailyRows = [];
  double _totalActiveDays = 0;
  double _totalSalary = 0;
  double _totalExpenses = 0;
  double _totalBraneyat = 0;
  double _totalAdditions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final year = int.parse(_selectedMonth.split('-')[0]);
    final month = int.parse(_selectedMonth.split('-')[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // جلب أيام النشاط
    final attendances = await db.query(
      'worker_attendance',
      where: 'worker_id = ? AND strftime("%Y-%m", date) = ?',
      whereArgs: [widget.workerId, _selectedMonth],
    );
    final activeDays = attendances.map((a) => a['date'] as String).toSet();

    // جلب المصاريف من worker_daily_expenses
    final expenses1 = await db.rawQuery('''
      SELECT date, COALESCE(SUM(amount), 0) as total
      FROM worker_daily_expenses
      WHERE worker_id = ? AND strftime("%Y-%m", date) = ?
      GROUP BY date
    ''', [widget.workerId, _selectedMonth]);

    // جلب المصاريف من worker_accounts (المصروف اليومي من المعرض)
    final expenses2 = await db.rawQuery('''
      SELECT transaction_date as date, COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableWorkerAccounts}
      WHERE worker_id = ? AND transaction_type = 'مصروف يومي' AND strftime("%Y-%m", transaction_date) = ?
      GROUP BY transaction_date
    ''', [widget.workerId, _selectedMonth]);

    // دمج المصاريف من المصدرين
    final expenseMap = <String, double>{};
    for (var e in expenses1) {
      expenseMap[e['date'] as String] = (e['total'] as num?)?.toDouble() ?? 0;
    }
    for (var e in expenses2) {
      final date = e['date'] as String;
      expenseMap[date] = (expenseMap[date] ?? 0) + ((e['total'] as num?)?.toDouble() ?? 0);
    }

    // جلب البرانيات
    final braneyat = await db.rawQuery('''
      SELECT transaction_date, COALESCE(SUM(amount), 0) as total
      FROM ${DBConstants.tableWorkerAccounts}
      WHERE worker_id = ? AND transaction_type = 'برانية' AND strftime("%Y-%m", transaction_date) = ?
      GROUP BY transaction_date
    ''', [widget.workerId, _selectedMonth]);
    final braneyatMap = {for (var b in braneyat) b['transaction_date'] as String: (b['total'] as num?)?.toDouble() ?? 0};

    // جلب الإضافات
    final additions = await db.rawQuery('''
      SELECT transaction_date, amount, description
      FROM ${DBConstants.tableWorkerAccounts}
      WHERE worker_id = ? AND transaction_type IN ('مكافأة', 'خصم', 'مستحق') AND strftime("%Y-%m", transaction_date) = ?
    ''', [widget.workerId, _selectedMonth]);
    final additionsMap = <String, List<Map<String, dynamic>>>{};
    for (var a in additions) {
      final date = a['transaction_date'] as String;
      additionsMap[date] ??= [];
      additionsMap[date]!.add(a);
    }

    // بناء الصفوف
    final rows = <Map<String, dynamic>>[];
    int totalDays = 0;
    double totalSalary = 0, totalExpenses = 0, totalBraneyat = 0, totalAdditions = 0;

    for (var d = 1; d <= daysInMonth; d++) {
      final date = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final isActive = activeDays.contains(date);
      final dayExpense = expenseMap[date] ?? 0;
      final dayBraneyat = braneyatMap[date] ?? 0;
      final dayAdditions = additionsMap[date] ?? [];
      final additionsTotal = dayAdditions.fold(0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0));

      if (isActive) {
        totalDays++;
        totalSalary += widget.dailySalary;
      }
      totalExpenses += dayExpense;
      totalBraneyat += dayBraneyat;
      totalAdditions += additionsTotal;

      rows.add({
        'date': date,
        'day': d,
        'isActive': isActive,
        'expense': dayExpense,
        'braneyat': dayBraneyat,
        'additions': dayAdditions,
        'additionsTotal': additionsTotal,
      });
    }

    setState(() {
      _dailyRows = rows;
      _totalActiveDays = totalDays.toDouble();
      _totalSalary = totalSalary;
      _totalExpenses = totalExpenses;
      _totalBraneyat = totalBraneyat;
      _totalAdditions = totalAdditions;
      _isLoading = false;
    });
  }

  Future<void> _toggleDay(int index) async {
    final row = _dailyRows[index];
    final date = row['date'] as String;
    final currentlyActive = row['isActive'] as bool;
    final db = await DatabaseHelper().database;

    if (currentlyActive) {
      await db.delete('worker_attendance', where: 'worker_id = ? AND date = ?', whereArgs: [widget.workerId, date]);
    } else {
      await db.insert('worker_attendance', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'worker_id': widget.workerId,
        'date': date,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    _loadMonthData();
  }

  Future<void> _addAddition(String date) async {
    final amountCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة ملحق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ', hintText: '0'), keyboardType: TextInputType.number),
            TextField(controller: detailsCtrl, decoration: const InputDecoration(labelText: 'التفاصيل')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              final db = await DatabaseHelper().database;
              await db.insert(DBConstants.tableWorkerAccounts, {
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'worker_id': widget.workerId,
                'transaction_type': 'مستحق',
                'amount': amount,
                'description': detailsCtrl.text.isNotEmpty ? detailsCtrl.text : 'إضافة',
                'transaction_date': date,
                'created_at': DateTime.now().toIso8601String(),
              });
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == true) _loadMonthData();
  }

  @override
  Widget build(BuildContext context) {
    final netSalary = _totalSalary - _totalExpenses - _totalBraneyat - _totalAdditions;

    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب: ${widget.workerName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                        final parts = _selectedMonth.split('-');
                        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) - 1, 1);
                        setState(() => _selectedMonth = d.toIso8601String().substring(0, 7));
                        _loadMonthData();
                      }),
                      Expanded(child: Center(child: Text(_selectedMonth, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
                        final parts = _selectedMonth.split('-');
                        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 1);
                        setState(() => _selectedMonth = d.toIso8601String().substring(0, 7));
                        _loadMonthData();
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _infoCard('الأجر اليومي', '${widget.dailySalary}'),
                          _infoCard('المصروف اليومي', '${widget.dailyExpense}'),
                          _infoCard('الحالة', widget.isActive ? 'نشط' : 'غير نشط'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('اليوم')),
                          DataColumn(label: Text('نشط')),
                          DataColumn(label: Text('مصروف')),
                          DataColumn(label: Text('برانيات')),
                          DataColumn(label: Text('إضافات')),
                          DataColumn(label: Text('إجراء')),
                        ],
                        rows: List.generate(_dailyRows.length, (index) {
                          final row = _dailyRows[index];
                          return DataRow(cells: [
                            DataCell(Text('${row['day']}')),
                            DataCell(Checkbox(value: row['isActive'] as bool, onChanged: (_) => _toggleDay(index))),
                            DataCell(Text('${row['expense']}')),
                            DataCell(Text('${row['braneyat']}')),
                            DataCell(Text('${row['additionsTotal']}')),
                            DataCell(IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor), onPressed: () => _addAddition(row['date'] as String))),
                          ]);
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.primaryColor.withAlpha(15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _summaryRow('إجمالي أيام النشاط', '${_totalActiveDays.toInt()} يوم'),
                          _summaryRow('إجمالي الراتب', '${_totalSalary.toStringAsFixed(0)}'),
                          _summaryRow('إجمالي المصاريف', '- ${_totalExpenses.toStringAsFixed(0)}'),
                          _summaryRow('إجمالي البرانيات', '- ${_totalBraneyat.toStringAsFixed(0)}'),
                          _summaryRow('إجمالي الإضافات', '- ${_totalAdditions.toStringAsFixed(0)}'),
                          const Divider(),
                          _summaryRow('💰 صافي الحساب', '${netSalary.toStringAsFixed(0)}', isBold: true, color: netSalary >= 0 ? AppTheme.successColor : AppTheme.errorColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14, color: color)),
        ],
      ),
    );
  }
}
