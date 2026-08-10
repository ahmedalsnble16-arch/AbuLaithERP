import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
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

  // بيانات ثابتة
  List<Product> _allProducts = [];
  List<Product> _products = [];
  List<Worker> _workers = [];
  bool _staticDataLoaded = false;

  String _businessDate = DateTime.now().toIso8601String().substring(0, 10);
  final TextEditingController _dateController = TextEditingController();

  // متحكمات السحبيات والمرتجعات
  final Map<String, TextEditingController> _loadBoxesCtrl = {};
  final Map<String, TextEditingController> _loadPiecesCtrl = {};
  final Map<String, TextEditingController> _returnBoxesCtrl = {};
  final Map<String, TextEditingController> _returnPiecesCtrl = {};

  // متحكمات المدور عليه
  final Map<String, TextEditingController> _remainingBoxesCtrl = {};
  final Map<String, TextEditingController> _remainingPiecesCtrl = {};

  Map<String, int> _yesterdayRemaining = {};

  // العمال
  Map<String, bool> _workerReceived = {};
  final Map<String, TextEditingController> _advanceCtrl = {};

  // الخرج اليومي
  final List<_DynamicRow> _expenseRows = [];

  // الكشف الصغير
  final List<_DynamicRow> _smallLedgerRows = [];

  // القات
  final List<_KhatRow> _khatRows = [];

  // كشف الحساب
  final TextEditingController _showroomExpenseCtrl = TextEditingController();
  final TextEditingController _cashReceivedCtrl = TextEditingController();
  bool _cashConfirmed = false;

  bool _isLoading = true;
  late TabController _tabController;

  // قيم اليوم السابق
  double _prevRemainingValue = 0.0;
  double _prevResultAmount = 0.0;

  // حالة الإغلاق والصلاحية
  bool _isDayClosed = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _dateController.text = _businessDate;
    _loadStaticDataAndThenDailyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateController.dispose();
    _disposeAllProductControllers();
    for (var c in _advanceCtrl.values) { c.dispose(); }
    _clearExpenseControllers();
    _clearSmallLedgerControllers();
    _clearKhatControllers();
    _showroomExpenseCtrl.dispose();
    _cashReceivedCtrl.dispose();
    super.dispose();
  }

  void _disposeAllProductControllers() {
    for (var c in _loadBoxesCtrl.values) { c.dispose(); }
    for (var c in _loadPiecesCtrl.values) { c.dispose(); }
    for (var c in _returnBoxesCtrl.values) { c.dispose(); }
    for (var c in _returnPiecesCtrl.values) { c.dispose(); }
    for (var c in _remainingBoxesCtrl.values) { c.dispose(); }
    for (var c in _remainingPiecesCtrl.values) { c.dispose(); }
    _loadBoxesCtrl.clear();
    _loadPiecesCtrl.clear();
    _returnBoxesCtrl.clear();
    _returnPiecesCtrl.clear();
    _remainingBoxesCtrl.clear();
    _remainingPiecesCtrl.clear();
  }

  void _clearExpenseControllers() {
    for (var row in _expenseRows) {
      row.amountCtrl.dispose();
      row.detailsCtrl.dispose();
    }
  }

  void _clearSmallLedgerControllers() {
    for (var row in _smallLedgerRows) {
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

  Future<String> _getCurrentUserRole() async => 'role_admin';

  Future<void> _loadStaticData() async {
    if (_staticDataLoaded) return;
    final products = await _productRepo.getAll();
    _allProducts = products;
    _products = products.where((p) => p.active).toList();
    _workers = await _workerRepo.getAll();
    _staticDataLoaded = true;
  }

  Future<void> _loadAllData() async {
    await _loadStaticData();
    await _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _rebuildProductControllersIfNeeded();

      // جلب مدور الأمس من daily_remaining
      _yesterdayRemaining.clear();
      final db = await _showroomRepo._dbHelper.database;
      for (var p in _products) {
        final remainingMaps = await db.query(
          'daily_remaining',
          columns: ['quantity'],
          where: 'product_id = ? AND remaining_date < ?',
          whereArgs: [p.id, _businessDate],
          orderBy: 'remaining_date DESC',
          limit: 1,
        );
        if (remainingMaps.isNotEmpty) {
          _yesterdayRemaining[p.id] = remainingMaps.first['quantity'] as int? ?? 0;
        } else {
          _yesterdayRemaining[p.id] = 0;
        }
      }

      for (var p in _products) {
        final entry = await _showroomRepo.getEntry(_businessDate, p.id);
        if (entry != null) {
          _loadBoxesCtrl[p.id]?.text = entry.loadBoxes.toString();
          _loadPiecesCtrl[p.id]?.text = entry.loadPieces.toString();
          _returnBoxesCtrl[p.id]?.text = entry.returnBoxes.toString();
          _returnPiecesCtrl[p.id]?.text = entry.returnPieces.toString();
        } else {
          _loadBoxesCtrl[p.id]?.text = '0';
          _loadPiecesCtrl[p.id]?.text = '0';
          _returnBoxesCtrl[p.id]?.text = '0';
          _returnPiecesCtrl[p.id]?.text = '0';
        }
      }

      for (var w in _workers) { _advanceCtrl[w.id]?.text = '0'; }
      _workerReceived = await _showroomRepo.getWorkerAttendance(_businessDate);

      final prevDay = DateTime.parse(_businessDate)
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final prevAccount = await _showroomRepo.getPreviousDayFull(prevDay);
      if (prevAccount != null) {
        _prevRemainingValue = (prevAccount['previous_remaining_value'] as num?)?.toDouble() ?? 0.0;
        _prevResultAmount = (prevAccount['result_amount'] as num?)?.toDouble() ?? 0.0;
      } else {
        _prevRemainingValue = 0.0;
        _prevResultAmount = 0.0;
      }

      await _loadExpenses();
      await _loadSmallLedger();
      await _loadKhat();

      final currentAccount = await _showroomRepo.getDailyAccount(_businessDate);
      if (currentAccount != null) {
        _showroomExpenseCtrl.text = (currentAccount['showroom_expense'] ?? 0).toString();
        _cashReceivedCtrl.text = (currentAccount['cash_received'] ?? 0).toString();
        _cashConfirmed = (currentAccount['cash_confirmed'] as int? ?? 0) == 1;
      } else {
        _showroomExpenseCtrl.text = '0';
        _cashReceivedCtrl.text = '0';
        _cashConfirmed = false;
      }

      _isDayClosed = await _showroomRepo.isDayClosed(_businessDate);
      final role = await _getCurrentUserRole();
      _isAdmin = (role == 'role_admin');
    } catch (e) {
      debugPrint('Error loading daily data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStaticDataAndThenDailyData() async {
    await _loadStaticData();
    _buildProductControllers();
    await _loadDailyData();
  }

  void _buildProductControllers() {
    for (var p in _products) {
      _loadBoxesCtrl[p.id] ??= TextEditingController(text: '0');
      _loadPiecesCtrl[p.id] ??= TextEditingController(text: '0');
      _returnBoxesCtrl[p.id] ??= TextEditingController(text: '0');
      _returnPiecesCtrl[p.id] ??= TextEditingController(text: '0');
      _remainingBoxesCtrl[p.id] ??= TextEditingController(text: '0');
      _remainingPiecesCtrl[p.id] ??= TextEditingController(text: '0');
    }
  }

  void _rebuildProductControllersIfNeeded() {
    for (var p in _products) {
      _loadBoxesCtrl[p.id] ??= TextEditingController(text: '0');
      _loadPiecesCtrl[p.id] ??= TextEditingController(text: '0');
      _returnBoxesCtrl[p.id] ??= TextEditingController(text: '0');
      _returnPiecesCtrl[p.id] ??= TextEditingController(text: '0');
      _remainingBoxesCtrl[p.id] ??= TextEditingController(text: '0');
      _remainingPiecesCtrl[p.id] ??= TextEditingController(text: '0');
    }
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
  }

  Future<void> _loadSmallLedger() async {
    final rows = await _showroomRepo.getSmallLedger(_businessDate);
    _clearSmallLedgerControllers();
    _smallLedgerRows.clear();
    if (rows.isEmpty) {
      _smallLedgerRows.add(_DynamicRow(id: _uuid.v4()));
    } else {
      for (var r in rows) {
        _smallLedgerRows.add(_DynamicRow(
          id: r['id']?.toString() ?? _uuid.v4(),
          amountCtrl: TextEditingController(text: '${r['amount'] ?? 0}'),
          detailsCtrl: TextEditingController(text: r['details'] ?? ''),
        ));
      }
    }
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
  }

  // ---------- دوال مساعدة ----------
  bool get _editable => !_isDayClosed;

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

  int _getCurrentRemainingPieces(String productId) {
    final yesterday = _yesterdayRemaining[productId] ?? 0;
    final load = _getLoadPieces(productId);
    final ret = _getReturnPieces(productId);
    return yesterday + load - ret;
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
        total += w.dailyExpense;
      }
    }
    return total;
  }

  double get _totalAdvances => _workers.fold(0.0,
      (sum, w) => sum + (double.tryParse(_advanceCtrl[w.id]?.text ?? '0') ?? 0));

  double get _totalDailyExpenses => _expenseRows.fold(
      0.0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));

  double get _totalSmallLedger => _smallLedgerRows.fold(
      0.0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));

  double get _totalKhat => _khatRows.fold(
      0.0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));

  // ---------- الحفظ ----------
  Future<void> _saveCurrentTab1() async {
    if (!_editable) return;
    final Map<String, int> availableStock = {};
    for (var p in _products) {
      availableStock[p.id] = await _showroomRepo.getAvailableStock(p.id);
    }

    final List<String> errors = [];
    for (var p in _products) {
      final needed = _getLoadPieces(p.id);
      if (needed > (availableStock[p.id] ?? 0)) {
        errors.add('${p.name}: المطلوب $needed، المتاح ${availableStock[p.id]}');
      }
    }
    if (errors.isNotEmpty) {
      _showErrorDialog('تجاوز المخزون', 'الكميات التالية أكبر من المخزون:\n${errors.join('\n')}');
      return;
    }

    final List<Map<String, dynamic>> entries = [];
    for (var p in _products) {
      entries.add({
        'productId': p.id,
        'loadBoxes': int.tryParse(_loadBoxesCtrl[p.id]?.text ?? '0') ?? 0,
        'loadPieces': int.tryParse(_loadPiecesCtrl[p.id]?.text ?? '0') ?? 0,
        'returnBoxes': int.tryParse(_returnBoxesCtrl[p.id]?.text ?? '0') ?? 0,
        'returnPieces': int.tryParse(_returnPiecesCtrl[p.id]?.text ?? '0') ?? 0,
        'boxSize': _getBoxSize(p.id),
        'retailPrice': _getRetailPrice(p.id),
      });
    }

    try {
      await _showroomRepo.saveAllEntries(
        businessDate: _businessDate,
        entries: entries,
        createdBy: 'admin',
        deviceId: 'mobile',
      );

      final db = await _showroomRepo._dbHelper.database;
      final now = DateTime.now().toIso8601String();
      for (var p in _products) {
        final boxes = int.tryParse(_remainingBoxesCtrl[p.id]?.text ?? '0') ?? 0;
        final pieces = int.tryParse(_remainingPiecesCtrl[p.id]?.text ?? '0') ?? 0;
        final totalPieces = (boxes * _getBoxSize(p.id)) + pieces;

        await db.delete(
          'daily_remaining',
          where: 'product_id = ? AND remaining_date = ?',
          whereArgs: [p.id, _businessDate],
        );
        await db.insert('daily_remaining', {
          'id': _uuid.v4(),
          'product_id': p.id,
          'remaining_date': _businessDate,
          'quantity': totalPieces,
          'boxes': boxes,
          'pieces': pieces,
          'created_at': now,
          'updated_at': now,
          'created_by': 'admin',
          'device_id': 'mobile',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ جميع بيانات اليوم بنجاح'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الحفظ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
      ),
    );
  }

  Future<void> _saveTab2() async {
    if (!_editable) return;
    try {
      for (var w in _workers) {
        final present = _workerReceived[w.id] ?? false;
        await _showroomRepo.setWorkerAttendance(workerId: w.id, date: _businessDate, present: present);
        if (present) {
          await _showroomRepo.recordWorkerDailyExpense(workerId: w.id, date: _businessDate, amount: w.dailyExpense, createdBy: 'admin', deviceId: 'mobile');
        }
        final advance = double.tryParse(_advanceCtrl[w.id]?.text ?? '0') ?? 0;
        if (advance > 0) {
          await _showroomRepo.saveWorkerAdvance(workerId: w.id, amount: advance, date: _businessDate, createdBy: 'admin', deviceId: 'mobile');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف العمال'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  Future<void> _saveExpenses() async {
    if (!_editable) return;
    try {
      final list = _expenseRows.map((row) => {'id': row.id, 'amount': double.tryParse(row.amountCtrl.text) ?? 0, 'details': row.detailsCtrl.text}).toList();
      await _showroomRepo.saveDailyExpenses(businessDate: _businessDate, expenses: list, createdBy: 'admin', deviceId: 'mobile');

      final db = await _showroomRepo._dbHelper.database;
      for (var row in _expenseRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        if (amount > 0) {
          await db.insert('treasury', {
            'id': _uuid.v4(),
            'transaction_number': 'EXP-$_businessDate-${DateTime.now().millisecondsSinceEpoch}',
            'transaction_type': 'صرف',
            'amount': amount,
            'source_module': 'معرض',
            'source_id': _businessDate,
            'payment_method': 'نقدي',
            'note': 'خرج يومي: ${row.detailsCtrl.text}',
            'transaction_date': _businessDate,
            'status': 'معتمدة',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'created_by': 'admin',
            'device_id': 'mobile',
            'sync_status': 'Pending',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الخرج اليومي وترحيله للخزنة'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  Future<void> _saveSmallLedger() async {
    if (!_editable) return;
    try {
      final list = _smallLedgerRows.map((row) => {'id': row.id, 'amount': double.tryParse(row.amountCtrl.text) ?? 0, 'details': row.detailsCtrl.text}).toList();
      await _showroomRepo.saveSmallLedger(businessDate: _businessDate, entries: list, createdBy: 'admin', deviceId: 'mobile');

      final db = await _showroomRepo._dbHelper.database;
      for (var row in _smallLedgerRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        if (amount > 0) {
          await db.insert('treasury', {
            'id': _uuid.v4(),
            'transaction_number': 'SLD-$_businessDate-${DateTime.now().millisecondsSinceEpoch}',
            'transaction_type': 'صرف',
            'amount': amount,
            'source_module': 'معرض',
            'source_id': _businessDate,
            'payment_method': 'نقدي',
            'note': 'كشف صغير: ${row.detailsCtrl.text}',
            'transaction_date': _businessDate,
            'status': 'معتمدة',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'created_by': 'admin',
            'device_id': 'mobile',
            'sync_status': 'Pending',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الكشف الصغير وترحيله للخزنة'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  Future<void> _saveKhat() async {
    if (!_editable) return;
    try {
      final list = _khatRows.map((row) => {'id': row.id, 'worker_name': row.workerNameCtrl.text, 'amount': double.tryParse(row.amountCtrl.text) ?? 0}).toList();
      await _showroomRepo.saveKhat(businessDate: _businessDate, entries: list, createdBy: 'admin', deviceId: 'mobile');

      final db = await _showroomRepo._dbHelper.database;
      for (var row in _khatRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        if (amount > 0) {
          await db.insert('treasury', {
            'id': _uuid.v4(),
            'transaction_number': 'KHT-$_businessDate-${DateTime.now().millisecondsSinceEpoch}',
            'transaction_type': 'صرف',
            'amount': amount,
            'source_module': 'معرض',
            'source_id': _businessDate,
            'payment_method': 'نقدي',
            'note': 'قات العمال: ${row.workerNameCtrl.text}',
            'transaction_date': _businessDate,
            'status': 'معتمدة',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'created_by': 'admin',
            'device_id': 'mobile',
            'sync_status': 'Pending',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف القات وترحيله للخزنة'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  Future<void> _saveAndCloseDay() async {
    if (!_editable) return;
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;

    // حساب قيمة المدور الفعلي الذي أدخله المستخدم اليوم
    double actualRemainingValue = 0;
    for (var p in _products) {
      final boxes = int.tryParse(_remainingBoxesCtrl[p.id]?.text ?? '0') ?? 0;
      final pieces = int.tryParse(_remainingPiecesCtrl[p.id]?.text ?? '0') ?? 0;
      final totalPieces = (boxes * _getBoxSize(p.id)) + pieces;
      actualRemainingValue += totalPieces * _getRetailPrice(p.id);
    }

    final previousDue = _prevRemainingValue + _prevResultAmount;
    final goodsNet = _totalLoadValue - _totalReturnValue;
    final totalDueFromGoods = previousDue + goodsNet;

    final totalExpenses = _totalWorkerExpenses + _totalAdvances + _totalDailyExpenses + _totalSmallLedger;
    final totalDue = totalDueFromGoods - totalExpenses + showroomExpense;

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
      previousRemainingValue: actualRemainingValue, // <-- استخدام القيمة الفعلية للمدور
      totalLoadValue: _totalLoadValue,
      totalReturnValue: _totalReturnValue,
      netGoodsValue: goodsNet,
      totalWorkerExpenses: _totalWorkerExpenses,
      totalWorkerAdvances: _totalAdvances,
      totalDailyExpenses: _totalDailyExpenses,
      totalSmallLedger: _totalSmallLedger,
      otherIncome: 0,
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

    setState(() => _isDayClosed = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ وإغلاق اليوم بنجاح'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  Future<void> _confirmCash() async {
    if (!_editable) return;
    try {
      await _showroomRepo.confirmCash(businessDate: _businessDate, confirmed: _cashConfirmed, confirmedBy: 'admin');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأكيد النقدية'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المعرض'),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: _printReport),
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportReport),
        ],
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

  void _printReport() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري إعداد التقرير للطباعة...')));
  void _exportReport() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تصدير التقرير...')));

  Widget _buildDateBar() {
    return Container(
      color: Theme.of(context).primaryColor.withAlpha(15),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { final d = DateTime.parse(_businessDate).subtract(const Duration(days: 1)); _businessDate = d.toIso8601String().substring(0, 10); _dateController.text = _businessDate; _loadDailyData(); }),
          Expanded(
            child: TextField(controller: _dateController, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'التاريخ', isDense: true, border: OutlineInputBorder()), onSubmitted: (v) { if (v.trim().isNotEmpty) { _businessDate = v.trim(); _loadDailyData(); } }),
          ),
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () { final d = DateTime.parse(_businessDate).add(const Duration(days: 1)); _businessDate = d.toIso8601String().substring(0, 10); _dateController.text = _businessDate; _loadDailyData(); }),
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
          Row(children: [
            _summaryCard('إجمالي السحبيات', _totalLoadValue, AppTheme.errorColor),
            _summaryCard('إجمالي المرتجعات', _totalReturnValue, AppTheme.successColor),
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
                      DataCell(SizedBox(width: 60, child: TextField(enabled: _editable, controller: _loadBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState((){})))),
                      DataCell(SizedBox(width: 60, child: TextField(enabled: _editable, controller: _loadPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState((){})))),
                      DataCell(SizedBox(width: 60, child: TextField(enabled: _editable, controller: _returnBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState((){})))),
                      DataCell(SizedBox(width: 60, child: TextField(enabled: _editable, controller: _returnPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState((){})))),
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
          // ***** قسم المدور عليه - إدخال مباشر *****
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📦 إدخال المدور عليه (البضاعة المتبقية فعلياً)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('المنتج')),
                        DataColumn(label: Text('سلال')),
                        DataColumn(label: Text('قطع')),
                        DataColumn(label: Text('سعر التجزئة')),
                        DataColumn(label: Text('القيمة الإجمالية')),
                      ],
                      rows: _products.map((p) {
                        final boxes = int.tryParse(_remainingBoxesCtrl[p.id]?.text ?? '0') ?? 0;
                        final pieces = int.tryParse(_remainingPiecesCtrl[p.id]?.text ?? '0') ?? 0;
                        final totalPieces = (boxes * _getBoxSize(p.id)) + pieces;
                        final value = totalPieces * _getRetailPrice(p.id);
                        return DataRow(cells: [
                          DataCell(Text(p.name)),
                          DataCell(SizedBox(width: 60, child: TextField(enabled: _editable, controller: _remainingBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState((){})))),
                          DataCell(SizedBox(width: 60, child: TextField(enabled: _editable, controller: _remainingPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState((){})))),
                          DataCell(Text('${_getRetailPrice(p.id)}')),
                          DataCell(Text('${value.toStringAsFixed(0)}')),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('إجمالي قيمة المدور عليه المدخل: ${_products.fold<double>(0, (sum, p) {
                    final boxes = int.tryParse(_remainingBoxesCtrl[p.id]?.text ?? '0') ?? 0;
                    final pieces = int.tryParse(_remainingPiecesCtrl[p.id]?.text ?? '0') ?? 0;
                    final totalPieces = (boxes * _getBoxSize(p.id)) + pieces;
                    return sum + (totalPieces * _getRetailPrice(p.id));
                  }).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _editable ? _saveCurrentTab1 : null,
            icon: const Icon(Icons.save),
            label: const Text('حفظ حركات اليوم والمدور عليه'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
          ),
        ],
      ),
    );
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
                      DataCell(Text('${w.dailyExpense}')),
                      DataCell(Checkbox(value: _workerReceived[w.id] ?? false, onChanged: _editable ? (v) => setState(() => _workerReceived[w.id] = v ?? false) : null)),
                      DataCell(SizedBox(width: 80, child: TextField(enabled: _editable, controller: _advanceCtrl[w.id], keyboardType: TextInputType.number, onChanged: (_) => setState((){})))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _editable ? _saveTab2 : null,
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
                    Expanded(flex: 2, child: TextField(enabled: _editable, controller: row.amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => setState((){}))),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: TextField(enabled: _editable, controller: row.detailsCtrl, decoration: const InputDecoration(labelText: 'التفاصيل', isDense: true))),
                    if (_editable) IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor), onPressed: () => setState(() => _expenseRows.removeAt(i))),
                  ],
                ),
              ),
            );
          }),
          if (_editable)
            Row(
              children: [
                Expanded(child: TextButton.icon(onPressed: () => setState(() => _expenseRows.add(_DynamicRow(id: _uuid.v4()))), icon: const Icon(Icons.add), label: const Text('إضافة صف'))),
                Expanded(child: ElevatedButton.icon(onPressed: _saveExpenses, icon: const Icon(Icons.save), label: const Text('حفظ الخرج وترحيله للخزنة'))),
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
    
    final previousDue = _prevRemainingValue + _prevResultAmount;
    final goodsNet = _totalLoadValue - _totalReturnValue;
    final totalDueFromGoods = previousDue + goodsNet;
    
    final totalExpenses = _totalWorkerExpenses + _totalAdvances + _totalDailyExpenses + _totalSmallLedger;
    final totalDue = totalDueFromGoods - totalExpenses + showroomExpense;
    final result = totalDue - cashReceived;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _accountTile('مدور البضاعة السابق (+)', _prevRemainingValue, color: AppTheme.primaryColor),
          _accountTile('العجز / الزيادة السابقة (مستحق)', _prevResultAmount, color: _prevResultAmount > 0 ? AppTheme.errorColor : (_prevResultAmount < 0 ? AppTheme.successColor : null)),
          _accountTile('قيمة السحبيات (+)', _totalLoadValue, color: AppTheme.errorColor),
          _accountTile('قيمة المرتجعات (-)', -_totalReturnValue, color: AppTheme.successColor),
          _accountTile('صافي حركة البضاعة اليوم', goodsNet),
          _accountTile('الالتزام الأساسي من البضاعة', totalDueFromGoods, bold: true),
          const Divider(),
          _accountTile('مصاريف العمال (-)', -_totalWorkerExpenses, color: AppTheme.successColor),
          _accountTile('البرانيات (-)', -_totalAdvances, color: AppTheme.successColor),
          _accountTile('الخرج اليومي (-)', -_totalDailyExpenses, color: AppTheme.successColor),
          _accountTile('إجمالي الكشف الصغير (-)', -_totalSmallLedger, color: AppTheme.successColor),
          _accountTile('مصروف المعرض (+) [سلفة/التزام]', showroomExpense, color: AppTheme.errorColor),
          
          // الكشف الصغير
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الكشف الصغير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...List.generate(_smallLedgerRows.length, (i) {
                    final row = _smallLedgerRows[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: TextField(enabled: _editable, controller: row.amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ', isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (_) => setState((){}))),
                          const SizedBox(width: 8),
                          Expanded(flex: 4, child: TextField(enabled: _editable, controller: row.detailsCtrl, decoration: const InputDecoration(labelText: 'التفاصيل', isDense: true, border: OutlineInputBorder()))),
                          if (_editable) IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor), onPressed: () => setState(() => _smallLedgerRows.removeAt(i))),
                        ],
                      ),
                    );
                  }),
                  if (_editable)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(onPressed: () => setState(() => _smallLedgerRows.add(_DynamicRow(id: _uuid.v4()))), icon: const Icon(Icons.add), label: const Text('إضافة صف')),
                        Text('إجمالي الكشف الصغير: $_totalSmallLedger', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ElevatedButton(onPressed: _saveSmallLedger, child: const Text('حفظ الكشف الصغير')),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          Card(
            child: ListTile(
              title: const Text('مصروف المعرض'),
              trailing: SizedBox(width: 120, child: TextField(enabled: _editable, controller: _showroomExpenseCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onChanged: (_) => setState((){}))),
            ),
          ),
          const Divider(thickness: 2),
          _accountTile('إجمالي المطلوب منه النهائي', totalDue, bold: true, color: AppTheme.primaryColor),
          Card(
            child: ListTile(
              title: const Text('الواصل نقداً', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: SizedBox(width: 120, child: TextField(enabled: _editable, controller: _cashReceivedCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onChanged: (_) => setState((){}))),
            ),
          ),
          if (_isAdmin) CheckboxListTile(title: const Text('تأكيد استلام النقدية (صلاحية المدير)'), value: _cashConfirmed, onChanged: _editable ? (v) { setState(() => _cashConfirmed = v ?? false); _confirmCash(); } : null)
          else ListTile(title: const Text('النقدية غير مؤكدة'), subtitle: const Text('تحتاج صلاحية المدير للتأكيد'), trailing: Icon(_cashConfirmed ? Icons.check_circle : Icons.cancel, color: _cashConfirmed ? AppTheme.successColor : AppTheme.warningColor)),
          const Divider(),
          Card(
            color: (result == 0) ? Colors.green.shade50 : (result > 0 ? Colors.red.shade50 : Colors.blue.shade50),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('النتيجة: ${result > 0 ? "عجز" : (result < 0 ? "زيادة" : "مطابق")}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: (result == 0) ? AppTheme.successColor : (result > 0 ? AppTheme.errorColor : AppTheme.primaryColor))),
                Text('${result.abs().toStringAsFixed(2)} ريال', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _editable ? _saveAndCloseDay : null,
            icon: const Icon(Icons.lock),
            label: const Text('حفظ وإغلاق اليومية'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }

  // ---------- التبويب 5 ----------
  Widget _buildTab5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _summaryCard('إجمالي القات', _totalKhat, AppTheme.warningColor),
          const SizedBox(height: 8),
          ...List.generate(_khatRows.length, (i) {
            final row = _khatRows[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(flex: 3, child: TextField(enabled: _editable, controller: row.workerNameCtrl, decoration: const InputDecoration(labelText: 'اسم العامل', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: TextField(enabled: _editable, controller: row.amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                  if (_editable) IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor), onPressed: () => setState(() => _khatRows.removeAt(i))),
                ]),
              ),
            );
          }),
          if (_editable)
            Row(
              children: [
                Expanded(child: TextButton.icon(onPressed: () => setState(() => _khatRows.add(_KhatRow(id: _uuid.v4()))), icon: const Icon(Icons.add), label: const Text('إضافة عامل'))),
                Expanded(child: ElevatedButton.icon(onPressed: _saveKhat, icon: const Icon(Icons.save), label: const Text('حفظ القات وترحيله للخزنة'))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(amount.toStringAsFixed(0), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _accountTile(String title, double amount, {bool bold = false, Color? color}) {
    return ListTile(
      dense: true,
      title: Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 15 : 13)),
      trailing: Text(amount.toStringAsFixed(2), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 15 : 13, color: color)),
    );
  }
}

// ---------- كائنات مساعدة ----------
class _DynamicRow {
  final String id;
  final TextEditingController amountCtrl;
  final TextEditingController detailsCtrl;

  _DynamicRow({required this.id, TextEditingController? amountCtrl, TextEditingController? detailsCtrl})
      : amountCtrl = amountCtrl ?? TextEditingController(text: '0'),
        detailsCtrl = detailsCtrl ?? TextEditingController();
}

class _KhatRow {
  final String id;
  final TextEditingController workerNameCtrl;
  final TextEditingController amountCtrl;

  _KhatRow({required this.id, TextEditingController? workerNameCtrl, TextEditingController? amountCtrl})
      : workerNameCtrl = workerNameCtrl ?? TextEditingController(),
        amountCtrl = amountCtrl ?? TextEditingController(text: '0');
}
