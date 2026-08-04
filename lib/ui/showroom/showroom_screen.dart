import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/models/worker.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/worker_repository.dart';

class ShowroomScreen extends StatefulWidget {
  const ShowroomScreen({super.key});

  @override
  State<ShowroomScreen> createState() => _ShowroomScreenState();
}

class _ShowroomScreenState extends State<ShowroomScreen>
    with SingleTickerProviderStateMixin {
  final ProductRepository _productRepo = ProductRepository();
  final WorkerRepository _workerRepo = WorkerRepository();

  List<Product> _products = [];
  List<Worker> _workers = [];

  String _businessDate = DateTime.now().toIso8601String().substring(0, 10);
  final TextEditingController _dateController = TextEditingController();

  // متحكمات السحبيات والمرتجعات
  final Map<String, TextEditingController> _loadBoxesCtrl = {};
  final Map<String, TextEditingController> _loadPiecesCtrl = {};
  final Map<String, TextEditingController> _returnBoxesCtrl = {};
  final Map<String, TextEditingController> _returnPiecesCtrl = {};

  // متحكمات العمال
  final Map<String, bool> _workerReceived = {};
  final Map<String, TextEditingController> _advanceCtrl = {};

  // متحكمات الخرج اليومي
  final List<TextEditingController> _expenseAmountCtrl = [];
  final List<TextEditingController> _expenseDetailsCtrl = [];

  // متحكمات قات العمال
  final List<TextEditingController> _khatNameCtrl = [];
  final List<TextEditingController> _khatAmountCtrl = [];

  // متحكمات الكشف الرسمي
  final TextEditingController _showroomExpenseCtrl = TextEditingController();
  final TextEditingController _cashReceivedCtrl = TextEditingController();
  final TextEditingController _otherIncomeAmountCtrl = TextEditingController();
  final TextEditingController _otherIncomeDetailsCtrl = TextEditingController();

  bool _isLoading = true;
  late TabController _tabController;

  // بيانات محملة
  double _prevRemaining = 0.0;
  List<Map<String, dynamic>> _dailyExpenses = [];
  List<Map<String, dynamic>> _khatEntries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _dateController.text = _businessDate;
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateController.dispose();
    for (var c in _loadBoxesCtrl.values) { c.dispose(); }
    for (var c in _loadPiecesCtrl.values) { c.dispose(); }
    for (var c in _returnBoxesCtrl.values) { c.dispose(); }
    for (var c in _returnPiecesCtrl.values) { c.dispose(); }
    for (var c in _advanceCtrl.values) { c.dispose(); }
    for (var c in _expenseAmountCtrl) { c.dispose(); }
    for (var c in _expenseDetailsCtrl) { c.dispose(); }
    for (var c in _khatNameCtrl) { c.dispose(); }
    for (var c in _khatAmountCtrl) { c.dispose(); }
    _showroomExpenseCtrl.dispose();
    _cashReceivedCtrl.dispose();
    _otherIncomeAmountCtrl.dispose();
    _otherIncomeDetailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      final products = await _productRepo.getAll();
      _products = products.where((p) => p.active).toList();
      for (var p in _products) {
        _loadBoxesCtrl[p.id] ??= TextEditingController(text: '0');
        _loadPiecesCtrl[p.id] ??= TextEditingController(text: '0');
        _returnBoxesCtrl[p.id] ??= TextEditingController(text: '0');
        _returnPiecesCtrl[p.id] ??= TextEditingController(text: '0');
      }

      _workers = await _workerRepo.getAll();
      for (var w in _workers) {
        _workerReceived[w.id] ??= false;
        _advanceCtrl[w.id] ??= TextEditingController(text: '0');
      }

      // رصيد مرحلة من اليوم السابق
      final yesterday = DateTime.parse(_businessDate).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
      final prevAccounts = await db.query('showroom_daily_account', where: 'business_date = ?', whereArgs: [yesterday]);
      _prevRemaining = prevAccounts.isNotEmpty ? (prevAccounts.first['result'] as num?)?.toDouble() ?? 0.0 : 0.0;

      _dailyExpenses = await db.query('showroom_daily_expenses', where: 'business_date = ?', whereArgs: [_businessDate]);
      _expenseAmountCtrl.clear();
      _expenseDetailsCtrl.clear();
      if (_dailyExpenses.isEmpty) {
        _dailyExpenses = [{'amount': 0, 'details': ''}];
      }
      for (var exp in _dailyExpenses) {
        _expenseAmountCtrl.add(TextEditingController(text: '${exp['amount'] ?? 0}'));
        _expenseDetailsCtrl.add(TextEditingController(text: exp['details'] ?? ''));
      }

      _khatEntries = await db.query('showroom_khat', where: 'business_date = ?', whereArgs: [_businessDate]);
      _khatNameCtrl.clear();
      _khatAmountCtrl.clear();
      if (_khatEntries.isEmpty) {
        _khatEntries = [{'worker_name': '', 'amount': 0}];
      }
      for (var k in _khatEntries) {
        _khatNameCtrl.add(TextEditingController(text: k['worker_name'] ?? ''));
        _khatAmountCtrl.add(TextEditingController(text: '${k['amount'] ?? 0}'));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  int _getBoxSize(String productId) {
    final product = _products.firstWhere((p) => p.id == productId, orElse: () => Product(id: '', name: '', createdAt: '', updatedAt: ''));
    return product.piecesPerBox;
  }

  double _getRetailPrice(String productId) {
    final product = _products.firstWhere((p) => p.id == productId, orElse: () => Product(id: '', name: '', createdAt: '', updatedAt: ''));
    return product.retailPrice;
  }

  int _getLoadPieces(String productId) {
    final boxes = int.tryParse(_loadBoxesCtrl[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_loadPiecesCtrl[productId]?.text ?? '0') ?? 0;
    return (boxes * _getBoxSize(productId)) + pieces;
  }

  int _getReturnPieces(String productId) {
    final boxes = int.tryParse(_returnBoxesCtrl[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_returnPiecesCtrl[productId]?.text ?? '0') ?? 0;
    return (boxes * _getBoxSize(productId)) + pieces;
  }

  double _getLoadValue(String productId) => _getLoadPieces(productId) * _getRetailPrice(productId);
  double _getReturnValue(String productId) => _getReturnPieces(productId) * _getRetailPrice(productId);

  double get _totalLoadValue => _products.fold(0, (sum, p) => sum + _getLoadValue(p.id));
  double get _totalReturnValue => _products.fold(0, (sum, p) => sum + _getReturnValue(p.id));
  double get _totalWorkerExpenses {
    double total = 0;
    for (var w in _workers) {
      if (_workerReceived[w.id] == true) total += w.salary;
    }
    return total;
  }
  double get _totalAdvances => _workers.fold(0, (sum, w) => sum + (double.tryParse(_advanceCtrl[w.id]?.text ?? '0') ?? 0));
  double get _totalDailyExpenses => _expenseAmountCtrl.fold(0, (sum, c) => sum + (double.tryParse(c.text) ?? 0));
  double get _totalKhat => _khatAmountCtrl.fold(0, (sum, c) => sum + (double.tryParse(c.text) ?? 0));

  Future<void> _saveDailyAccount() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeAmountCtrl.text) ?? 0;
    final totalDue = _prevRemaining + _totalLoadValue - _totalReturnValue + _totalWorkerExpenses + _totalAdvances + _totalDailyExpenses + showroomExpense - otherIncome;
    final result = totalDue - cashReceived;

    await db.insert(
      'showroom_daily_account',
      {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'business_date': _businessDate,
        'total_load_value': _totalLoadValue,
        'total_return_value': _totalReturnValue,
        'total_worker_expenses': _totalWorkerExpenses,
        'total_worker_advances': _totalAdvances,
        'total_daily_expenses': _totalDailyExpenses,
        'showroom_expense': showroomExpense,
        'cash_received': cashReceived,
        'other_income': otherIncome,
        'result': result,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الحساب اليومي'), backgroundColor: AppTheme.successColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المعرض'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'السحبيات والمرتجعات'),
            Tab(text: 'العمال والمصاريف'),
            Tab(text: 'الخرج اليومي'),
            Tab(text: 'كشف الحساب'),
            Tab(text: 'قات العمال'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                        final d = DateTime.parse(_businessDate).subtract(const Duration(days: 1));
                        _businessDate = d.toIso8601String().substring(0, 10);
                        _dateController.text = _businessDate;
                        _loadAllData();
                      }),
                      Expanded(child: TextField(controller: _dateController, decoration: const InputDecoration(labelText: 'التاريخ'), onSubmitted: (v) { _businessDate = v; _loadAllData(); })),
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
                        final d = DateTime.parse(_businessDate).add(const Duration(days: 1));
                        _businessDate = d.toIso8601String().substring(0, 10);
                        _dateController.text = _businessDate;
                        _loadAllData();
                      }),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTab1(),
                      _buildTab2(),
                      _buildTab3(),
                      _buildTab4(),
                      _buildTab5(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTab1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(children: [
            _summaryCard('السحبيات', _totalLoadValue, AppTheme.errorColor),
            _summaryCard('المرتجعات', _totalReturnValue, AppTheme.successColor),
            _summaryCard('الصافي', _totalLoadValue - _totalReturnValue, AppTheme.primaryColor),
          ]),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('المنتج')),
                    DataColumn(label: Text('سلة')),
                    DataColumn(label: Text('سحب (سلال)')),
                    DataColumn(label: Text('سحب (قطع)')),
                    DataColumn(label: Text('مرتجع (سلال)')),
                    DataColumn(label: Text('مرتجع (قطع)')),
                    DataColumn(label: Text('قيمة السحب')),
                    DataColumn(label: Text('قيمة المرتجع')),
                    DataColumn(label: Text('الصافي')),
                  ],
                  rows: _products.map((p) {
                    return DataRow(cells: [
                      DataCell(Text(p.name)),
                      DataCell(Text('${p.piecesPerBox}')),
                      DataCell(SizedBox(width: 50, child: TextField(controller: _loadBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                      DataCell(SizedBox(width: 50, child: TextField(controller: _loadPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                      DataCell(SizedBox(width: 50, child: TextField(controller: _returnBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                      DataCell(SizedBox(width: 50, child: TextField(controller: _returnPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                      DataCell(Text('${_getLoadValue(p.id).toStringAsFixed(0)}')),
                      DataCell(Text('${_getReturnValue(p.id).toStringAsFixed(0)}')),
                      DataCell(Text('${(_getLoadValue(p.id) - _getReturnValue(p.id)).toStringAsFixed(0)}')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(children: [
            _summaryCard('إجمالي المصاريف', _totalWorkerExpenses, AppTheme.warningColor),
            _summaryCard('إجمالي البرانيات', _totalAdvances, AppTheme.errorColor),
          ]),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('العامل')),
                    DataColumn(label: Text('المصروف اليومي')),
                    DataColumn(label: Text('استلم ✓')),
                    DataColumn(label: Text('برانية')),
                  ],
                  rows: _workers.map((w) {
                    return DataRow(cells: [
                      DataCell(Text(w.name)),
                      DataCell(Text('${w.salary}')),
                      DataCell(Checkbox(value: _workerReceived[w.id] ?? false, onChanged: (v) => setState(() => _workerReceived[w.id] = v ?? false))),
                      DataCell(SizedBox(width: 80, child: TextField(controller: _advanceCtrl[w.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _summaryCard('إجمالي الخرج', _totalDailyExpenses, AppTheme.errorColor),
          ...(_dailyExpenses.asMap().entries.map((e) {
            final i = e.key;
            return Card(
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _expenseAmountCtrl[i], decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number)),
                  Expanded(child: TextField(controller: _expenseDetailsCtrl[i], decoration: const InputDecoration(labelText: 'التفاصيل'))),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }

  Widget _buildTab4() {
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeAmountCtrl.text) ?? 0;
    final totalDue = _prevRemaining + _totalLoadValue - _totalReturnValue + _totalWorkerExpenses + _totalAdvances + _totalDailyExpenses + showroomExpense - otherIncome;
    final result = totalDue - cashReceived;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Card(child: ListTile(title: const Text('المدور عليه من اليوم السابق'), trailing: Text('${_prevRemaining.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('قيمة السحبيات'), trailing: Text('${_totalLoadValue.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('قيمة المرتجعات'), trailing: Text('- ${_totalReturnValue.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('مصاريف العمال'), trailing: Text('${_totalWorkerExpenses.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('البرانيات'), trailing: Text('${_totalAdvances.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('الخرج اليومي'), trailing: Text('${_totalDailyExpenses.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('مصروف المعرض'), trailing: SizedBox(width: 100, child: TextField(controller: _showroomExpenseCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
          Card(child: ListTile(title: const Text('إيرادات أخرى'), trailing: SizedBox(width: 100, child: TextField(controller: _otherIncomeAmountCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
          const Divider(),
          Card(color: AppTheme.primaryColor.withAlpha(20), child: ListTile(title: const Text('المطلوب منه', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('${totalDue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)))),
          Card(child: ListTile(title: const Text('الواصل نقداً'), trailing: SizedBox(width: 100, child: TextField(controller: _cashReceivedCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
          const Divider(),
          Card(color: result == 0 ? AppTheme.successColor.withAlpha(20) : AppTheme.errorColor.withAlpha(20), child: ListTile(
            title: Text(result > 0 ? 'ضائع / عجز' : result < 0 ? 'زيادة' : 'الحساب مطابق', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('${result.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: result == 0 ? AppTheme.successColor : AppTheme.errorColor)),
          )),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _saveDailyAccount, icon: const Icon(Icons.save), label: const Text('حفظ وإغلاق اليوم')),
        ],
      ),
    );
  }

  Widget _buildTab5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _summaryCard('إجمالي قات العمال', _totalKhat, AppTheme.warningColor),
          ...(_khatEntries.asMap().entries.map((e) {
            final i = e.key;
            return Card(
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _khatNameCtrl[i], decoration: const InputDecoration(labelText: 'العامل'))),
                  Expanded(child: TextField(controller: _khatAmountCtrl[i], decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number)),
                ],
              ),
            );
          })),
          const SizedBox(height: 8),
          TextButton(onPressed: () {
            _khatEntries.add({'worker_name': '', 'amount': 0});
            _khatNameCtrl.add(TextEditingController());
            _khatAmountCtrl.add(TextEditingController(text: '0'));
            setState(() {});
          }, child: const Text('+ إضافة صف')),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 11)),
              Text('${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
