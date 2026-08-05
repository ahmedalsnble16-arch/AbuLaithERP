import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/models/worker.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/worker_repository.dart';
import '../../data/repositories/treasury_repository.dart';

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

  // الخرج اليومي التفاعلي
  final List<_ExpenseRow> _expenseRows = [];

  // قات العمال التفاعلي
  final List<_KhatRow> _khatRows = [];

  // متحكمات الكشف الرسمي
  final TextEditingController _showroomExpenseCtrl = TextEditingController();
  final TextEditingController _cashReceivedCtrl = TextEditingController();
  final TextEditingController _otherIncomeAmountCtrl = TextEditingController();

  bool _isLoading = true;
  late TabController _tabController;
  double _prevRemaining = 0.0;

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
    for (var row in _expenseRows) {
      row.amountCtrl.dispose();
      row.detailsCtrl.dispose();
    }
    for (var row in _khatRows) {
      row.amountCtrl.dispose();
      row.detailsCtrl.dispose();
    }
    _showroomExpenseCtrl.dispose();
    _cashReceivedCtrl.dispose();
    _otherIncomeAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      final products = await _productRepo.getAll();
      _products = products.where((p) => p.active).toList();
      for (var p in _products) {
        _loadBoxesCtrl[p.id] ??= TextEditingController();
        _loadPiecesCtrl[p.id] ??= TextEditingController();
        _returnBoxesCtrl[p.id] ??= TextEditingController();
        _returnPiecesCtrl[p.id] ??= TextEditingController();
      }

      _workers = await _workerRepo.getAll();
      for (var w in _workers) {
        _workerReceived[w.id] ??= false;
        _advanceCtrl[w.id] ??= TextEditingController();
      }

      // رصيد مرحل
      final yesterday = DateTime.parse(_businessDate).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
      final prevAccounts = await db.query('showroom_daily_account', where: 'business_date = ?', whereArgs: [yesterday]);
      _prevRemaining = prevAccounts.isNotEmpty ? (prevAccounts.first['result'] as num?)?.toDouble() ?? 0.0 : 0.0;

      // تحميل الخرج اليومي
      await _loadExpenses();

      // تحميل القات
      await _loadKhat();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadExpenses() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('showroom_daily_expenses', where: 'business_date = ?', whereArgs: [_businessDate]);
    _expenseRows.clear();
    if (rows.isEmpty) {
      _expenseRows.add(_ExpenseRow());
    } else {
      for (var r in rows) {
        _expenseRows.add(_ExpenseRow(
          id: r['id']?.toString(),
          amountCtrl: TextEditingController(text: '${r['amount'] ?? 0}'),
          detailsCtrl: TextEditingController(text: (r['details'] ?? '').toString()),
        ));
      }
    }
  }

  Future<void> _loadKhat() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('showroom_khat', where: 'business_date = ?', whereArgs: [_businessDate]);
    _khatRows.clear();
    if (rows.isEmpty) {
      _khatRows.add(_KhatRow());
    } else {
      for (var r in rows) {
        _khatRows.add(_KhatRow(
          id: r['id']?.toString(),
          amountCtrl: TextEditingController(text: '${r['amount'] ?? 0}'),
          detailsCtrl: TextEditingController(text: (r['details'] ?? '').toString()),
        ));
      }
    }
  }

  Future<void> _saveExpenses() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;
    await db.transaction((txn) async {
      await txn.delete('showroom_daily_expenses', where: 'business_date = ?', whereArgs: [_businessDate]);
      for (var row in _expenseRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        if (amount <= 0 && row.detailsCtrl.text.trim().isEmpty) continue;
        await txn.insert('showroom_daily_expenses', {
          'id': row.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'business_date': _businessDate,
          'amount': amount,
          'details': row.detailsCtrl.text,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف الخرج اليومي'), backgroundColor: AppTheme.successColor));
    }
    await _loadExpenses();
    setState(() {});
  }

  Future<void> _saveKhat() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;
    await db.transaction((txn) async {
      await txn.delete('showroom_khat', where: 'business_date = ?', whereArgs: [_businessDate]);
      for (var row in _khatRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        if (amount <= 0 && row.detailsCtrl.text.trim().isEmpty) continue;
        await txn.insert('showroom_khat', {
          'id': row.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'business_date': _businessDate,
          'amount': amount,
          'details': row.detailsCtrl.text,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف قات العمال'), backgroundColor: AppTheme.successColor));
    }
    await _loadKhat();
    setState(() {});
  }

  Future<void> _saveWorkersAndAdvances() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;
    
    await db.transaction((txn) async {
      // حفظ استلام العمال لمصاريفهم
      await txn.delete('showroom_worker_received', where: 'business_date = ?', whereArgs: [_businessDate]);
      for (var w in _workers) {
        if (_workerReceived[w.id] == true) {
          await txn.insert('showroom_worker_received', {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'business_date': _businessDate,
            'worker_id': w.id,
            'worker_name': w.name,
            'salary': w.salary,
            'created_at': now,
          });
        }
      }

      // حفظ البرانيات (السلف) للعمال
      await txn.delete('showroom_worker_advances', where: 'business_date = ?', whereArgs: [_businessDate]);
      for (var w in _workers) {
        final advance = double.tryParse(_advanceCtrl[w.id]?.text ?? '') ?? 0;
        if (advance > 0) {
          await txn.insert('showroom_worker_advances', {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'business_date': _businessDate,
            'worker_id': w.id,
            'worker_name': w.name,
            'amount': advance,
            'created_at': now,
          });

          // تسجيل الحركة في حساب العامل
          await txn.insert('worker_accounts', {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'worker_id': w.id,
            'transaction_type': 'برانية',
            'amount': advance,
            'description': 'برانية من المعرض بتاريخ $_businessDate',
            'transaction_date': _businessDate,
            'created_at': now,
            'sync_status': 'Pending',
          });
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات العمال والبرانيات'), backgroundColor: AppTheme.successColor));
    }
  }

  // ---------- حسابات السحبيات والعمال ----------
  int _getBoxSize(String productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    return product.piecesPerBox;
  }

  double _getRetailPrice(String productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    return product.retailPrice;
  }

  int _getLoadPieces(String productId) {
    final boxes = int.tryParse(_loadBoxesCtrl[productId]?.text ?? '') ?? 0;
    final pieces = int.tryParse(_loadPiecesCtrl[productId]?.text ?? '') ?? 0;
    return (boxes * _getBoxSize(productId)) + pieces;
  }

  int _getReturnPieces(String productId) {
    final boxes = int.tryParse(_returnBoxesCtrl[productId]?.text ?? '') ?? 0;
    final pieces = int.tryParse(_returnPiecesCtrl[productId]?.text ?? '') ?? 0;
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
  double get _totalAdvances => _workers.fold(0, (sum, w) => sum + (double.tryParse(_advanceCtrl[w.id]?.text ?? '') ?? 0));
  double get _totalExpenses => _expenseRows.fold(0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));
  double get _totalKhat => _khatRows.fold(0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));

  Future<void> _saveDailyAccount() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeAmountCtrl.text) ?? 0;
    final totalDue = _prevRemaining + _totalLoadValue - _totalReturnValue + _totalWorkerExpenses + _totalAdvances + _totalExpenses + showroomExpense - otherIncome;
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
        'total_daily_expenses': _totalExpenses,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ وإغلاق اليوم'), backgroundColor: AppTheme.successColor));
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
                // شريط التاريخ
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

  // ============ التبويب 1: السحبيات والمرتجعات ============
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
                      DataCell(SizedBox(width: 50, child: TextField(controller: _loadBoxesCtrl[p.id], decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                      DataCell(SizedBox(width: 50, child: TextField(controller: _loadPiecesCtrl[p.id], decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                      DataCell(SizedBox(width: 50, child: TextField(controller: _returnBoxesCtrl[p.id], decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                      DataCell(SizedBox(width: 50, child: TextField(controller: _returnPiecesCtrl[p.id], decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
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

  // ============ التبويب 2: العمال والمصاريف ============
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
                      DataCell(SizedBox(width: 80, child: TextField(controller: _advanceCtrl[w.id], decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveWorkersAndAdvances,
            icon: const Icon(Icons.save),
            label: const Text('حفظ بيانات العمال والبرانيات'),
          ),
        ],
      ),
    );
  }

  // ============ التبويب 3: الخرج اليومي التفاعلي ============
  Widget _buildTab3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _summaryCard('إجمالي الخرج اليومي', _totalExpenses, AppTheme.errorColor),
          const SizedBox(height: 8),
          ...List.generate(_expenseRows.length, (i) {
            final row = _expenseRows[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.amountCtrl,
                        decoration: const InputDecoration(labelText: 'المبلغ', hintText: '0'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.detailsCtrl,
                        decoration: const InputDecoration(labelText: 'التفاصيل'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                      onPressed: () {
                        setState(() {
                          _expenseRows.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _expenseRows.add(_ExpenseRow());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة صف'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveExpenses,
            icon: const Icon(Icons.save),
            label: const Text('حفظ كشف الخرج اليومي'),
          ),
        ],
      ),
    );
  }

  // ============ التبويب 4: كشف الحساب الرسمي ============
  Widget _buildTab4() {
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeAmountCtrl.text) ?? 0;
    final totalDue = _prevRemaining + _totalLoadValue - _totalReturnValue + _totalWorkerExpenses + _totalAdvances + _totalExpenses + showroomExpense - otherIncome;
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
          Card(child: ListTile(title: const Text('الخرج اليومي'), trailing: Text('${_totalExpenses.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('مصروف المعرض'), trailing: SizedBox(width: 100, child: TextField(controller: _showroomExpenseCtrl, decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
          Card(child: ListTile(title: const Text('إيرادات أخرى'), trailing: SizedBox(width: 100, child: TextField(controller: _otherIncomeAmountCtrl, decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
          const Divider(),
          Card(color: AppTheme.primaryColor.withAlpha(20), child: ListTile(title: const Text('المطلوب منه', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('${totalDue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)))),
          Card(child: ListTile(title: const Text('الواصل نقداً'), trailing: SizedBox(width: 100, child: TextField(controller: _cashReceivedCtrl, decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
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

  // ============ التبويب 5: قات العمال التفاعلي ============
  Widget _buildTab5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _summaryCard('إجمالي قات العمال', _totalKhat, AppTheme.warningColor),
          const SizedBox(height: 8),
          ...List.generate(_khatRows.length, (i) {
            final row = _khatRows[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.amountCtrl,
                        decoration: const InputDecoration(labelText: 'المبلغ', hintText: '0'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: row.detailsCtrl,
                        decoration: const InputDecoration(labelText: 'التفاصيل'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                      onPressed: () {
                        setState(() {
                          _khatRows.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _khatRows.add(_KhatRow());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة صف'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveKhat,
            icon: const Icon(Icons.save),
            label: const Text('حفظ كشف قات العمال'),
          ),
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

// ---------- كائنات مساعدة ----------
class _ExpenseRow {
  String? id;
  final TextEditingController amountCtrl;
  final TextEditingController detailsCtrl;

  _ExpenseRow({this.id, TextEditingController? amountCtrl, TextEditingController? detailsCtrl})
      : amountCtrl = amountCtrl ?? TextEditingController(),
        detailsCtrl = detailsCtrl ?? TextEditingController();
}

class _KhatRow {
  String? id;
  final TextEditingController amountCtrl;
  final TextEditingController detailsCtrl;

  _KhatRow({this.id, TextEditingController? amountCtrl, TextEditingController? detailsCtrl})
      : amountCtrl = amountCtrl ?? TextEditingController(),
        detailsCtrl = detailsCtrl ?? TextEditingController();
}
