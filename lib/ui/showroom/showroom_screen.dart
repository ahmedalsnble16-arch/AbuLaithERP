import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/models/worker.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/worker_repository.dart';
import '../../data/repositories/showroom_repository.dart';

class ShowroomScreen extends StatefulWidget {
  const ShowroomScreen({super.key});

  @override
  State<ShowroomScreen> createState() => _ShowroomScreenState();
}

class _ShowroomScreenState extends State<ShowroomScreen>
    with SingleTickerProviderStateMixin {
  final ProductRepository _productRepo = ProductRepository();
  final WorkerRepository _workerRepo = WorkerRepository();
  final ShowroomRepository _showroomRepo = ShowroomRepository();
  final Uuid _uuid = const Uuid();

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
  Map<String, bool> _workerReceived = {};
  final Map<String, TextEditingController> _advanceCtrl = {};

  // الخرج اليومي
  final List<_DynamicRow> _expenseRows = [];
  bool _expensesLoaded = false;

  // قات العمال
  final List<_KhatRow> _khatRows = [];
  bool _khatLoaded = false;

  // كشف الحساب
  final TextEditingController _showroomExpenseCtrl = TextEditingController();
  final TextEditingController _cashReceivedCtrl = TextEditingController();
  final TextEditingController _otherIncomeAmountCtrl = TextEditingController();
  bool _cashConfirmed = false;

  bool _isLoading = true;
  late TabController _tabController;
  double _prevRemainingValue = 0.0; // قيمة مدور أمس (بالبضاعة)

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
    _clearExpenseControllers();
    _clearKhatControllers();
    _showroomExpenseCtrl.dispose();
    _cashReceivedCtrl.dispose();
    _otherIncomeAmountCtrl.dispose();
    super.dispose();
  }

  void _clearExpenseControllers() {
    for (var row in _expenseRows) {
      row.amountCtrl.dispose();
      row.detailsCtrl.dispose();
    }
  }

  void _clearKhatControllers() {
    for (var row in _khatRows) {
      row.workerNameCtrl.dispose();
      row.amountCtrl.dispose();
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      // المنتجات
      final products = await _productRepo.getAll();
      _products = products.where((p) => p.active).toList();
      for (var p in _products) {
        _loadBoxesCtrl[p.id] ??= TextEditingController(text: '0');
        _loadPiecesCtrl[p.id] ??= TextEditingController(text: '0');
        _returnBoxesCtrl[p.id] ??= TextEditingController(text: '0');
        _returnPiecesCtrl[p.id] ??= TextEditingController(text: '0');
      }

      // تحميل بيانات اليوم الحالي للمنتجات (إن وجدت)
      for (var p in _products) {
        final entry = await _showroomRepo.getEntry(_businessDate, p.id);
        if (entry != null) {
          _loadBoxesCtrl[p.id]?.text = entry.loadBoxes.toString();
          _loadPiecesCtrl[p.id]?.text = entry.loadPieces.toString();
          _returnBoxesCtrl[p.id]?.text = entry.returnBoxes.toString();
          _returnPiecesCtrl[p.id]?.text = entry.returnPieces.toString();
        }
      }

      // العمال
      _workers = await _workerRepo.getAll();
      for (var w in _workers) {
        _advanceCtrl[w.id] ??= TextEditingController(text: '0');
      }
      // تحميل حضور اليوم
      _workerReceived = await _showroomRepo.getWorkerAttendance(_businessDate);

      // الرصيد المرحل (قيمة مدور البضاعة من الأمس)
      final yesterday = DateTime.parse(_businessDate)
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final prevAccount = await _showroomRepo.getDailyAccount(yesterday);
      if (prevAccount != null) {
        _prevRemainingValue = (prevAccount['previous_remaining_value'] as num?)?.toDouble() ?? 0.0;
      } else {
        _prevRemainingValue = 0.0;
      }

      // تحميل الخرج اليومي
      await _loadExpenses();

      // تحميل القات
      await _loadKhat();

      // تحميل كشف الحساب الرسمي إن وجد
      final currentAccount = await _showroomRepo.getDailyAccount(_businessDate);
      if (currentAccount != null) {
        _showroomExpenseCtrl.text = (currentAccount['showroom_expense'] ?? 0).toString();
        _cashReceivedCtrl.text = (currentAccount['cash_received'] ?? 0).toString();
        _otherIncomeAmountCtrl.text = (currentAccount['other_income'] ?? 0).toString();
        _cashConfirmed = (currentAccount['cash_confirmed'] as int? ?? 0) == 1;
      } else {
        _showroomExpenseCtrl.text = '0';
        _cashReceivedCtrl.text = '0';
        _otherIncomeAmountCtrl.text = '0';
        _cashConfirmed = false;
      }

    } catch (e) {
      debugPrint('Error loading showroom: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadExpenses() async {
    final rows = await _showroomRepo.getDailyExpenses(_businessDate);
    _clearExpenseControllers();
    _expenseRows.clear();
    if (rows.isEmpty) {
      _expenseRows.add(_DynamicRow(id: _uuid.v4()));
    } else {
      for (var r in rows) {
        _expenseRows.add(_DynamicRow(
          id: r['id']?.toString() ?? _uuid.v4(),
          amountCtrl: TextEditingController(text: '${r['amount'] ?? 0}'),
          detailsCtrl: TextEditingController(text: r['details'] ?? ''),
        ));
      }
    }
    _expensesLoaded = true;
  }

  Future<void> _loadKhat() async {
    final rows = await _showroomRepo.getKhatEntries(_businessDate);
    _clearKhatControllers();
    _khatRows.clear();
    if (rows.isEmpty) {
      _khatRows.add(_KhatRow(id: _uuid.v4()));
    } else {
      for (var r in rows) {
        _khatRows.add(_KhatRow(
          id: r['id']?.toString() ?? _uuid.v4(),
          workerNameCtrl: TextEditingController(text: r['worker_name'] ?? ''),
          amountCtrl: TextEditingController(text: '${r['amount'] ?? 0}'),
        ));
      }
    }
    _khatLoaded = true;
  }

  // ---------- الحسابات المساعدة ----------
  int _getBoxSize(String productId) {
    final p = _products.firstWhere((e) => e.id == productId,
        orElse: () => Product(id: '', name: '', createdAt: '', updatedAt: ''));
    return p.piecesPerBox;
  }

  double _getRetailPrice(String productId) {
    final p = _products.firstWhere((e) => e.id == productId,
        orElse: () => Product(id: '', name: '', createdAt: '', updatedAt: ''));
    return p.retailPrice;
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

  double _getLoadValue(String productId) =>
      _getLoadPieces(productId) * _getRetailPrice(productId);

  double _getReturnValue(String productId) =>
      _getReturnPieces(productId) * _getRetailPrice(productId);

  double get _totalLoadValue =>
      _products.fold(0.0, (sum, p) => sum + _getLoadValue(p.id));

  double get _totalReturnValue =>
      _products.fold(0.0, (sum, p) => sum + _getReturnValue(p.id));

  double get _totalWorkerExpenses {
    double total = 0;
    for (var w in _workers) {
      if (_workerReceived[w.id] == true) {
        total += w.dailyExpense; // استخدم dailyExpense بدلاً من salary
      }
    }
    return total;
  }

  double get _totalAdvances => _workers.fold(0.0,
      (sum, w) => sum + (double.tryParse(_advanceCtrl[w.id]?.text ?? '0') ?? 0));

  double get _totalDailyExpenses => _expenseRows.fold(
      0.0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));

  double get _totalKhat => _khatRows.fold(
      0.0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));

  // ---------- عمليات الحفظ ----------
  Future<void> _saveCurrentTab1() async {
    try {
      for (var p in _products) {
        await _showroomRepo.saveEntry(
          businessDate: _businessDate,
          productId: p.id,
          loadBoxes: int.tryParse(_loadBoxesCtrl[p.id]?.text ?? '0') ?? 0,
          loadPieces: int.tryParse(_loadPiecesCtrl[p.id]?.text ?? '0') ?? 0,
          returnBoxes: int.tryParse(_returnBoxesCtrl[p.id]?.text ?? '0') ?? 0,
          returnPieces: int.tryParse(_returnPiecesCtrl[p.id]?.text ?? '0') ?? 0,
          boxSize: _getBoxSize(p.id),
          retailPrice: _getRetailPrice(p.id),
          createdBy: 'admin', // يجب استبداله بالمستخدم الفعلي
          deviceId: 'mobile',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ حركات السحب والمرتجعات'),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _saveTab2() async {
    try {
      // حفظ الحضور
      for (var w in _workers) {
        await _showroomRepo.setWorkerAttendance(
          workerId: w.id,
          date: _businessDate,
          present: _workerReceived[w.id] ?? false,
        );
      }
      // حفظ البرانيات (فقط إذا كانت القيمة > 0)
      for (var w in _workers) {
        final advance = double.tryParse(_advanceCtrl[w.id]?.text ?? '0') ?? 0;
        if (advance > 0) {
          await _showroomRepo.saveWorkerAdvance(
            workerId: w.id,
            amount: advance,
            date: _businessDate,
            createdBy: 'admin',
            deviceId: 'mobile',
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ كشف العمال'),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _saveExpenses() async {
    try {
      final List<Map<String, dynamic>> list = _expenseRows.map((row) => {
        'id': row.id,
        'amount': double.tryParse(row.amountCtrl.text) ?? 0,
        'details': row.detailsCtrl.text,
      }).toList();
      await _showroomRepo.saveDailyExpenses(
        businessDate: _businessDate,
        expenses: list,
        createdBy: 'admin',
        deviceId: 'mobile',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الخرج اليومي'),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _saveKhat() async {
    try {
      final List<Map<String, dynamic>> list = _khatRows.map((row) => {
        'id': row.id,
        'worker_name': row.workerNameCtrl.text,
        'amount': double.tryParse(row.amountCtrl.text) ?? 0,
      }).toList();
      await _showroomRepo.saveKhat(
        businessDate: _businessDate,
        entries: list,
        createdBy: 'admin',
        deviceId: 'mobile',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ كشف القات'),
              backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _saveAndCloseDay() async {
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeAmountCtrl.text) ?? 0;
    final netGoods = _totalLoadValue - _totalReturnValue;
    final totalDue = _prevRemainingValue +
        _totalLoadValue -
        _totalReturnValue +
        _totalWorkerExpenses +
        _totalAdvances +
        _totalDailyExpenses +
        showroomExpense -
        otherIncome;
    final result = totalDue - cashReceived;
    String status;
    if (result > 0) {
      status = 'عجز';
    } else if (result < 0) {
      status = 'زيادة';
    } else {
      status = 'مطابق';
    }

    await _showroomRepo.saveDailyAccount(
      businessDate: _businessDate,
      previousRemainingValue: _prevRemainingValue,
      totalLoadValue: _totalLoadValue,
      totalReturnValue: _totalReturnValue,
      netGoodsValue: netGoods,
      totalWorkerExpenses: _totalWorkerExpenses,
      totalWorkerAdvances: _totalAdvances,
      totalDailyExpenses: _totalDailyExpenses,
      otherIncome: otherIncome,
      showroomExpense: showroomExpense,
      totalDue: totalDue,
      cashReceived: cashReceived,
      cashConfirmed: _cashConfirmed,
      confirmedBy: _cashConfirmed ? 'admin' : null,
      resultAmount: result,
      resultStatus: status,
      closed: true,
      closedBy: 'admin',
      createdBy: 'admin',
      deviceId: 'mobile',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ وإغلاق اليوم بنجاح'),
            backgroundColor: AppTheme.successColor),
      );
    }
  }

  // ---------- واجهة المستخدم ----------
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
                _buildDateBar(),
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

  Widget _buildDateBar() {
    return Container(
      color: Theme.of(context).primaryColor.withAlpha(15),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final d = DateTime.parse(_businessDate).subtract(const Duration(days: 1));
              _businessDate = d.toIso8601String().substring(0, 10);
              _dateController.text = _businessDate;
              _loadAllData();
            },
          ),
          Expanded(
            child: TextField(
              controller: _dateController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'التاريخ',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _businessDate = v.trim();
                  _loadAllData();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final d = DateTime.parse(_businessDate).add(const Duration(days: 1));
              _businessDate = d.toIso8601String().substring(0, 10);
              _dateController.text = _businessDate;
              _loadAllData();
            },
          ),
        ],
      ),
    );
  }

  // ---------- التبويب 1 ----------
  Widget _buildTab1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // بطاقات ملخص
          Row(children: [
            _summaryCard('إجمالي السحبيات', _totalLoadValue, AppTheme.errorColor),
            _summaryCard('إجمالي المرتجعات', _totalReturnValue, AppTheme.successColor),
            _summaryCard('الصافي', _totalLoadValue - _totalReturnValue, AppTheme.primaryColor),
          ]),
          const SizedBox(height: 8),
          // جدول المنتجات
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('المنتج')),
                    DataColumn(label: Text('سلة (قطعة)')),
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
                      DataCell(SizedBox(width: 60, child: TextField(
                          controller: _loadBoxesCtrl[p.id],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState((){})))),
                      DataCell(SizedBox(width: 60, child: TextField(
                          controller: _loadPiecesCtrl[p.id],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState((){})))),
                      DataCell(SizedBox(width: 60, child: TextField(
                          controller: _returnBoxesCtrl[p.id],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState((){})))),
                      DataCell(SizedBox(width: 60, child: TextField(
                          controller: _returnPiecesCtrl[p.id],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState((){})))),
                      DataCell(Text('${_getLoadValue(p.id).toStringAsFixed(0)}')),
                      DataCell(Text('${_getReturnValue(p.id).toStringAsFixed(0)}')),
                      DataCell(Text('${(_getLoadValue(p.id) - _getReturnValue(p.id)).toStringAsFixed(0)}')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // قسم المدور عليه
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📦 المدور عليه (البضاعة المتبقية في المعرض)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._products.map((p) {
                    final loadPieces = _getLoadPieces(p.id);
                    final returnPieces = _getReturnPieces(p.id);
                    // المدور = (مدور أمس) + سحب - مرتجع
                    // نعتمد على القيمة المخزنة في showroom_daily_entries عند التحميل
                    // هنا للعرض فقط بناءً على القيم المدخلة
                    return ListTile(
                      title: Text(p.name),
                      trailing: Text(
                        '${_getRemainingDisplay(p.id)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _saveCurrentTab1,
            icon: const Icon(Icons.save),
            label: const Text('حفظ حركات السحب والمرتجعات'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
          ),
        ],
      ),
    );
  }

  String _getRemainingDisplay(String productId) {
    // محاولة قراءة القيمة المحفوظة من الـ entries التي تم تحميلها مسبقاً
    // لكن لتبسيط نعرض حساباً تقريبياً
    final load = _getLoadPieces(productId);
    final ret = _getReturnPieces(productId);
    return '${load - ret} قطعة';
  }

  // ---------- التبويب 2 ----------
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
                      DataCell(Text('${w.dailyExpense}')), // استخدام dailyExpense
                      DataCell(Checkbox(
                          value: _workerReceived[w.id] ?? false,
                          onChanged: (v) {
                            setState(() => _workerReceived[w.id] = v ?? false);
                          })),
                      DataCell(SizedBox(
                          width: 80,
                          child: TextField(
                              controller: _advanceCtrl[w.id],
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState((){})))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _saveTab2,
            icon: const Icon(Icons.save),
            label: const Text('حفظ كشف العمال'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
          ),
        ],
      ),
    );
  }

  // ---------- التبويب 3 ----------
  Widget _buildTab3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryCard('إجمالي الخرج اليومي', _totalDailyExpenses, AppTheme.errorColor),
          const SizedBox(height: 8),
          ...List.generate(_expenseRows.length, (i) {
            final row = _expenseRows[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.amountCtrl,
                        decoration: const InputDecoration(labelText: 'المبلغ', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState((){}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: row.detailsCtrl,
                        decoration: const InputDecoration(labelText: 'التفاصيل', isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                      onPressed: () => setState(() => _expenseRows.removeAt(i)),
                    ),
                  ],
                ),
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => setState(() => _expenseRows.add(_DynamicRow(id: _uuid.v4()))),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة صف'),
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveExpenses,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ الخرج'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- التبويب 4 ----------
  Widget _buildTab4() {
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;
    final otherIncome = double.tryParse(_otherIncomeAmountCtrl.text) ?? 0;
    final totalDue = _prevRemainingValue +
        _totalLoadValue -
        _totalReturnValue +
        _totalWorkerExpenses +
        _totalAdvances +
        _totalDailyExpenses +
        showroomExpense -
        otherIncome;
    final result = totalDue - cashReceived;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _accountTile('المدور عليه من اليوم السابق', _prevRemainingValue),
          _accountTile('قيمة السحبيات', _totalLoadValue),
          _accountTile('قيمة المرتجعات', -_totalReturnValue),
          _accountTile('صافي حركة البضاعة', _totalLoadValue - _totalReturnValue),
          _accountTile('مصاريف العمال', _totalWorkerExpenses),
          _accountTile('البرانيات', _totalAdvances),
          _accountTile('الخرج اليومي', _totalDailyExpenses, color: AppTheme.errorColor),
          ListTile(
            title: const Text('مصروف المعرض'),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: _showroomExpenseCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState((){}),
              ),
            ),
          ),
          ListTile(
            title: const Text('إيرادات أخرى'),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: _otherIncomeAmountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState((){}),
              ),
            ),
          ),
          const Divider(),
          _accountTile('المطلوب منه', totalDue, bold: true),
          ListTile(
            title: const Text('الواصل نقداً'),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: _cashReceivedCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState((){}),
              ),
            ),
          ),
          CheckboxListTile(
            title: const Text('تأكيد استلام النقدية'),
            value: _cashConfirmed,
            onChanged: (v) => setState(() => _cashConfirmed = v ?? false),
          ),
          const Divider(),
          Card(
            color: (result == 0)
                ? AppTheme.successColor.withAlpha(20)
                : AppTheme.errorColor.withAlpha(20),
            child: ListTile(
              title: Text(
                result > 0 ? 'ضائع / عجز' : (result < 0 ? 'زيادة' : 'الحساب مطابق'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text('${result.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: result == 0 ? AppTheme.successColor : AppTheme.errorColor)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveAndCloseDay,
            icon: const Icon(Icons.lock),
            label: const Text('حفظ وإغلاق اليوم'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
          ),
        ],
      ),
    );
  }

  Widget _accountTile(String title, double amount, {bool bold = false, Color? color}) {
    return Card(
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        trailing: Text('${amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
      ),
    );
  }

  // ---------- التبويب 5 ----------
  Widget _buildTab5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryCard('إجمالي قات العمال', _totalKhat, AppTheme.warningColor),
          const SizedBox(height: 8),
          ...List.generate(_khatRows.length, (i) {
            final row = _khatRows[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.workerNameCtrl,
                        decoration: const InputDecoration(labelText: 'اسم العامل', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.amountCtrl,
                        decoration: const InputDecoration(labelText: 'المبلغ', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState((){}),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                      onPressed: () => setState(() => _khatRows.removeAt(i)),
                    ),
                  ],
                ),
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => setState(() => _khatRows.add(_KhatRow(id: _uuid.v4()))),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة صف'),
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveKhat,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ القات'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${amount.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- كائنات مساعدة ----------
class _DynamicRow {
  final String id;
  final TextEditingController amountCtrl;
  final TextEditingController detailsCtrl;

  _DynamicRow({
    required this.id,
    TextEditingController? amountCtrl,
    TextEditingController? detailsCtrl,
  })  : amountCtrl = amountCtrl ?? TextEditingController(text: '0'),
        detailsCtrl = detailsCtrl ?? TextEditingController();
}

class _KhatRow {
  final String id;
  final TextEditingController workerNameCtrl;
  final TextEditingController amountCtrl;

  _KhatRow({
    required this.id,
    TextEditingController? workerNameCtrl,
    TextEditingController? amountCtrl,
  })  : workerNameCtrl = workerNameCtrl ?? TextEditingController(),
        amountCtrl = amountCtrl ?? TextEditingController(text: '0');
}
