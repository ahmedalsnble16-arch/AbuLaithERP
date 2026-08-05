import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
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

class _ExpenseRow {
  String? id;
  TextEditingController amountCtrl;
  TextEditingController detailsCtrl;
  _ExpenseRow({this.id, TextEditingController? amountCtrl, TextEditingController? detailsCtrl})
      : amountCtrl = amountCtrl ?? TextEditingController(),
        detailsCtrl = detailsCtrl ?? TextEditingController();
}

class _KhatRow {
  String? id;
  String workerId;
  String workerName;
  TextEditingController amountCtrl;
  TextEditingController detailsCtrl;
  _KhatRow({
    this.id,
    this.workerId = '',
    this.workerName = '',
    TextEditingController? amountCtrl,
    TextEditingController? detailsCtrl,
  })  : amountCtrl = amountCtrl ?? TextEditingController(),
        detailsCtrl = detailsCtrl ?? TextEditingController();
}

class _MinorExpenseRow {
  String? id;
  TextEditingController amountCtrl;
  TextEditingController detailsCtrl;
  _MinorExpenseRow({this.id, TextEditingController? amountCtrl, TextEditingController? detailsCtrl})
      : amountCtrl = amountCtrl ?? TextEditingController(),
        detailsCtrl = detailsCtrl ?? TextEditingController();
}

class _ShowroomScreenState extends State<ShowroomScreen>
    with SingleTickerProviderStateMixin {
  final ProductRepository _productRepo = ProductRepository();
  final WorkerRepository _workerRepo = WorkerRepository();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Worker> _workers = [];

  String _businessDate = DateTime.now().toIso8601String().substring(0, 10);
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // السحبيات والمرتجعات
  final Map<String, TextEditingController> _loadBoxesCtrl = {};
  final Map<String, TextEditingController> _loadPiecesCtrl = {};
  final Map<String, TextEditingController> _returnBoxesCtrl = {};
  final Map<String, TextEditingController> _returnPiecesCtrl = {};

  // المدور عليه (البضاعة المتبقية في المعرض)
  final Map<String, TextEditingController> _remBoxesCtrl = {};
  final Map<String, TextEditingController> _remPiecesCtrl = {};

  // العمال والبرانيات
  final Map<String, bool> _workerReceived = {};
  final Map<String, TextEditingController> _advanceCtrl = {};

  // الخرج الكشوفات
  final List<_ExpenseRow> _expenseRows = [];
  final List<_KhatRow> _khatRows = [];
  final List<_MinorExpenseRow> _minorExpenseRows = [];

  // الحساب المالي
  final TextEditingController _showroomExpenseCtrl = TextEditingController();
  final TextEditingController _cashReceivedCtrl = TextEditingController();

  bool _isLoading = true;
  late TabController _tabController;
  double _prevRemaining = 0.0;
  bool _loadsAndReturnsSaved = false;

  Map<String, int> _previousLoads = {};
  Map<String, int> _previousReturns = {};

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
    _searchController.dispose();
    for (var c in _loadBoxesCtrl.values) { c.dispose(); }
    for (var c in _loadPiecesCtrl.values) { c.dispose(); }
    for (var c in _returnBoxesCtrl.values) { c.dispose(); }
    for (var c in _returnPiecesCtrl.values) { c.dispose(); }
    for (var c in _remBoxesCtrl.values) { c.dispose(); }
    for (var c in _remPiecesCtrl.values) { c.dispose(); }
    for (var c in _advanceCtrl.values) { c.dispose(); }
    for (var r in _expenseRows) { r.amountCtrl.dispose(); r.detailsCtrl.dispose(); }
    for (var r in _khatRows) { r.amountCtrl.dispose(); r.detailsCtrl.dispose(); }
    for (var r in _minorExpenseRows) { r.amountCtrl.dispose(); r.detailsCtrl.dispose(); }
    _showroomExpenseCtrl.dispose();
    _cashReceivedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      final products = await _productRepo.getAll();
      _products = products.where((p) => p.active).toList();
      _filteredProducts = List.from(_products);

      for (var p in _products) {
        _loadBoxesCtrl[p.id] ??= TextEditingController();
        _loadPiecesCtrl[p.id] ??= TextEditingController();
        _returnBoxesCtrl[p.id] ??= TextEditingController();
        _returnPiecesCtrl[p.id] ??= TextEditingController();
        _remBoxesCtrl[p.id] ??= TextEditingController();
        _remPiecesCtrl[p.id] ??= TextEditingController();
      }

      _workers = await _workerRepo.getAll();
      for (var w in _workers) {
        _workerReceived[w.id] ??= false;
        _advanceCtrl[w.id] ??= TextEditingController();
      }

      // الرصيد المرحل والنتيجة السابقة
      final yesterday = DateTime.parse(_businessDate).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
      final prevAccounts = await db.query('showroom_daily_closing', where: 'business_date = ?', whereArgs: [yesterday]);
      if (prevAccounts.isNotEmpty) {
        _prevRemaining = (prevAccounts.first['result_amount'] as num?)?.toDouble() ?? 0.0;
      } else {
        _prevRemaining = 0.0;
      }

      await _loadExpenses();
      await _loadKhat();
      await _loadMinorExpenses();
      await _checkIfAlreadySaved();
      await _loadPreviousEntries();
      await _loadRemainingInventory();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products.where((p) => p.name.contains(query)).toList();
      }
    });
  }

  Future<void> _checkIfAlreadySaved() async {
    final db = await DatabaseHelper().database;
    final entries = await db.query('showroom_daily_entries', where: 'business_date = ?', whereArgs: [_businessDate]);
    _loadsAndReturnsSaved = entries.isNotEmpty;

    _previousLoads.clear();
    _previousReturns.clear();
    if (entries.isNotEmpty) {
      for (var e in entries) {
        final productId = e['product_id'] as String;
        final loadBoxes = e['load_boxes'] as int? ?? 0;
        final loadPieces = e['load_pieces'] as int? ?? 0;
        final returnBoxes = e['return_boxes'] as int? ?? 0;
        final returnPieces = e['return_pieces'] as int? ?? 0;
        final boxSize = e['box_size'] as int? ?? 60;

        _previousLoads[productId] = (loadBoxes * boxSize) + loadPieces;
        _previousReturns[productId] = (returnBoxes * boxSize) + returnPieces;
      }
    }
  }

  Future<void> _loadPreviousEntries() async {
    final db = await DatabaseHelper().database;
    final entries = await db.query('showroom_daily_entries', where: 'business_date = ?', whereArgs: [_businessDate]);
    for (var e in entries) {
      final productId = e['product_id'] as String;
      _loadBoxesCtrl[productId]?.text = '${e['load_boxes'] ?? 0}';
      _loadPiecesCtrl[productId]?.text = '${e['load_pieces'] ?? 0}';
      _returnBoxesCtrl[productId]?.text = '${e['return_boxes'] ?? 0}';
      _returnPiecesCtrl[productId]?.text = '${e['return_pieces'] ?? 0}';
    }
  }

  Future<void> _loadRemainingInventory() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('showroom_daily_inventory_remaining', where: 'business_date = ?', whereArgs: [_businessDate]);
    for (var r in rows) {
      final pId = r['product_id'] as String;
      _remBoxesCtrl[pId]?.text = '${r['boxes'] ?? 0}';
      _remPiecesCtrl[pId]?.text = '${r['pieces'] ?? 0}';
    }
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

  Future<void> _loadMinorExpenses() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('showroom_minor_expenses', where: 'business_date = ?', whereArgs: [_businessDate]);
    _minorExpenseRows.clear();
    if (rows.isEmpty) {
      _minorExpenseRows.add(_MinorExpenseRow());
    } else {
      for (var r in rows) {
        _minorExpenseRows.add(_MinorExpenseRow(
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
          workerId: (r['worker_id'] ?? '').toString(),
          workerName: (r['worker_name'] ?? '').toString(),
          amountCtrl: TextEditingController(text: '${r['amount'] ?? 0}'),
          detailsCtrl: TextEditingController(text: (r['details'] ?? '').toString()),
        ));
      }
    }
  }

  // ============ حفظ السحبيات والمرتجعات والربط التكاملي مع المخزن ============
  Future<void> _saveLoadsAndReturns() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    try {
      await db.transaction((txn) async {
        // 1. عكس الحركات القديمة عند إعادة الحفظ لمنع Double Posting
        if (_loadsAndReturnsSaved) {
          for (var entry in _previousLoads.entries) {
            final productId = entry.key;
            final oldLoad = entry.value;
            final oldReturn = _previousReturns[productId] ?? 0;

            if (oldLoad > 0) {
              final stockList = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [productId]);
              if (stockList.isNotEmpty) {
                final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
                await txn.update(DBConstants.tableStock, {'quantity_pieces': currentQty + oldLoad, 'updated_at': now}, where: 'product_id = ?', whereArgs: [productId]);
              }
            }

            if (oldReturn > 0) {
              final stockList = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [productId]);
              if (stockList.isNotEmpty) {
                final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
                final newQty = currentQty - oldReturn;
                await txn.update(DBConstants.tableStock, {'quantity_pieces': newQty < 0 ? 0 : newQty, 'updated_at': now}, where: 'product_id = ?', whereArgs: [productId]);
              }
            }
          }
        }

        // 2. تطبيق الحركات الجديدة
        for (var p in _products) {
          final loadPieces = _getLoadPieces(p.id);
          final returnPieces = _getReturnPieces(p.id);

          if (loadPieces > 0) {
            final stockList = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [p.id]);
            if (stockList.isNotEmpty) {
              final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
              if (currentQty < loadPieces) {
                throw Exception('الكمية المطلوبة أكبر من المخزون المتاح للمنتج (${p.name}): المتاح $currentQty، المطلوب $loadPieces');
              }
              final afterQty = currentQty - loadPieces;
              await txn.update(DBConstants.tableStock, {'quantity_pieces': afterQty, 'updated_at': now}, where: 'product_id = ?', whereArgs: [p.id]);

              await txn.insert(DBConstants.tableStockMovements, {
                'id': DateTime.now().millisecondsSinceEpoch.toString() + '_l_${p.id}',
                'product_id': p.id,
                'movement_type': 'showroom_load',
                'before_quantity': currentQty,
                'quantity': -loadPieces,
                'after_quantity': afterQty,
                'reference_id': _businessDate,
                'reference_type': 'showroom',
                'notes': 'سحب معرض بتاريخ $_businessDate',
                'created_at': now,
                'sync_status': 'Pending',
              });
            }
          }

          if (returnPieces > 0) {
            final stockList = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [p.id]);
            int currentQty = 0;
            if (stockList.isNotEmpty) {
              currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
              final afterQty = currentQty + returnPieces;
              await txn.update(DBConstants.tableStock, {'quantity_pieces': afterQty, 'updated_at': now}, where: 'product_id = ?', whereArgs: [p.id]);
            } else {
              await txn.insert(DBConstants.tableStock, {
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'product_id': p.id,
                'quantity_pieces': returnPieces,
                'reserved_quantity': 0,
                'average_cost': p.productionCost,
                'last_update': now,
                'created_at': now,
                'updated_at': now,
              });
            }

            await txn.insert(DBConstants.tableStockMovements, {
              'id': DateTime.now().millisecondsSinceEpoch.toString() + '_r_${p.id}',
              'product_id': p.id,
              'movement_type': 'showroom_return',
              'before_quantity': currentQty,
              'quantity': returnPieces,
              'after_quantity': currentQty + returnPieces,
              'reference_id': _businessDate,
              'reference_type': 'showroom',
              'notes': 'مرتجع معرض بتاريخ $_businessDate',
              'created_at': now,
              'sync_status': 'Pending',
            });
          }

          if (loadPieces > 0 || returnPieces > 0) {
            await txn.insert(
              'showroom_daily_entries',
              {
                'id': DateTime.now().millisecondsSinceEpoch.toString() + '_entry_${p.id}',
                'business_date': _businessDate,
                'product_id': p.id,
                'load_boxes': int.tryParse(_loadBoxesCtrl[p.id]?.text ?? '') ?? 0,
                'load_pieces': int.tryParse(_loadPiecesCtrl[p.id]?.text ?? '') ?? 0,
                'return_boxes': int.tryParse(_returnBoxesCtrl[p.id]?.text ?? '') ?? 0,
                'return_pieces': int.tryParse(_returnPiecesCtrl[p.id]?.text ?? '') ?? 0,
                'box_size': p.piecesPerBox,
                'retail_price': p.retailPrice,
                'created_at': now,
                'updated_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          // 3. حفظ المدور عليه (البضاعة المتبقية)
          final remPieces = _getRemainingPieces(p.id);
          if (remPieces > 0) {
            await txn.insert(
              'showroom_daily_inventory_remaining',
              {
                'id': DateTime.now().millisecondsSinceEpoch.toString() + '_rem_${p.id}',
                'business_date': _businessDate,
                'product_id': p.id,
                'boxes': int.tryParse(_remBoxesCtrl[p.id]?.text ?? '') ?? 0,
                'pieces': int.tryParse(_remPiecesCtrl[p.id]?.text ?? '') ?? 0,
                'total_pieces': remPieces,
                'retail_price': p.retailPrice,
                'total_value': remPieces * p.retailPrice,
                'created_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        _loadsAndReturnsSaved = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ السحبيات والمرتجعات وتحديث مخزن الإنتاج والمدور عليه بنجاح'), backgroundColor: AppTheme.successColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  // ============ حفظ العمال والبرانيات ============
  Future<void> _saveWorkersAndAdvances() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    await db.transaction((txn) async {
      await txn.delete('showroom_worker_received', where: 'business_date = ?', whereArgs: [_businessDate]);
      await txn.delete('showroom_worker_advances', where: 'business_date = ?', whereArgs: [_businessDate]);

      for (var w in _workers) {
        final isActive = _workerReceived[w.id] == true;
        final advance = double.tryParse(_advanceCtrl[w.id]?.text ?? '') ?? 0;

        if (isActive) {
          await txn.insert('worker_accounts', {
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_w_${w.id}',
            'worker_id': w.id,
            'transaction_type': 'مستحق',
            'amount': w.salary,
            'description': 'أجر يومي مستحق عن المعرض بتاريخ $_businessDate',
            'transaction_date': _businessDate,
            'created_at': now,
            'sync_status': 'Pending',
          });

          await txn.insert('showroom_worker_received', {
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_rec_${w.id}',
            'business_date': _businessDate,
            'worker_id': w.id,
            'worker_name': w.name,
            'salary': w.salary,
            'created_at': now,
          });
        }

        if (advance > 0) {
          await txn.insert('worker_accounts', {
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_adv_${w.id}',
            'worker_id': w.id,
            'transaction_type': 'برانية',
            'amount': -advance,
            'description': 'برانية من المعرض بتاريخ $_businessDate',
            'transaction_date': _businessDate,
            'created_at': now,
            'sync_status': 'Pending',
          });

          await txn.insert('showroom_worker_advances', {
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_sh_adv_${w.id}',
            'business_date': _businessDate,
            'worker_id': w.id,
            'worker_name': w.name,
            'amount': advance,
            'created_at': now,
          });
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ مصاريف العمال والبرانيات وتمريرها لكشوف حساباتهم'), backgroundColor: AppTheme.successColor));
    }
  }

  // ============ حفظ الخرج اليومي للربط مع المدير المالي ============
  Future<void> _saveExpenses() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    await db.transaction((txn) async {
      await txn.delete('showroom_daily_expenses', where: 'business_date = ?', whereArgs: [_businessDate]);
      for (var row in _expenseRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        final details = row.detailsCtrl.text;
        if (amount > 0) {
          await txn.insert('showroom_daily_expenses', {
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_exp_${row.hashCode}',
            'business_date': _businessDate,
            'amount': amount,
            'details': details,
            'approval_status': 'Pending',
            'created_at': now,
          });
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الخرج اليومي وترحيله للمدير المالي'), backgroundColor: AppTheme.successColor));
    }
  }

  // ============ حفظ قات العمال ============
  Future<void> _saveKhat() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    await db.transaction((txn) async {
      await txn.delete('showroom_khat', where: 'business_date = ?', whereArgs: [_businessDate]);
      for (var row in _khatRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        final details = row.detailsCtrl.text;
        if (amount > 0) {
          await txn.insert('showroom_khat', {
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_khat_${row.hashCode}',
            'business_date': _businessDate,
            'worker_id': row.workerId,
            'worker_name': row.workerName.isNotEmpty ? row.workerName : details,
            'amount': amount,
            'details': details,
            'created_at': now,
          });
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف قات العمال كملحق مستقل بنجاح'), backgroundColor: AppTheme.successColor));
    }
  }

  // ============ حفظ وإغلاق اليوم والتصدير لصفحة المقارنة الكلية ============
  Future<void> _saveDailyAccount() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;

    // المكونات الحسابية
    final totalDue = _prevRemaining + _totalLoadValue + showroomExpense;
    final totalCoverage = _totalReturnValue + _totalWorkerExpenses + _totalAdvances + _totalExpenses + _totalMinorExpenses + cashReceived;
    final resultAmount = totalDue - totalCoverage;

    String resultType = 'matched';
    if (resultAmount > 0) {
      resultType = 'deficit';
    } else if (resultAmount < 0) {
      resultType = 'surplus';
    }

    await db.transaction((txn) async {
      // حفظ الكشف الصغير
      await txn.delete('showroom_minor_expenses', where: 'business_date = ?', whereArgs: [_businessDate]);
      for (var row in _minorExpenseRows) {
        final amount = double.tryParse(row.amountCtrl.text) ?? 0;
        if (amount > 0) {
          await txn.insert('showroom_minor_expenses', {
            'id': DateTime.now().millisecondsSinceEpoch.toString() + '_min_${row.hashCode}',
            'business_date': _businessDate,
            'amount': amount,
            'details': row.detailsCtrl.text,
            'created_at': now,
          });
        }
      }

      // حفظ الإغلاق المالي لليوم (تصدير مرجوع المعرض والنتيجة الكلية)
      await txn.insert(
        'showroom_daily_closing',
        {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'business_date': _businessDate,
          'prev_remaining': _prevRemaining,
          'total_load_value': _totalLoadValue,
          'total_return_value': _totalReturnValue, // يُصدر لصفحة المقارنة الكلية
          'total_worker_expenses': _totalWorkerExpenses,
          'total_advances': _totalAdvances,
          'total_daily_expenses': _totalExpenses,
          'showroom_expense': showroomExpense,
          'minor_expenses_total': _totalMinorExpenses,
          'total_due': totalDue,
          'cash_received': cashReceived,
          'cash_approval_status': 'Pending',
          'result_amount': resultAmount,
          'result_type': resultType,
          'closed_by': 'المستخدم الحالي',
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ وإغلاق اليوم وتصدير المرجوع لصفحة المقارنة الكلية بنجاح'), backgroundColor: AppTheme.successColor));
    }
  }

  // ============ الحسابات الرياضية ============
  int _getBoxSize(String productId) => _products.firstWhere((p) => p.id == productId).piecesPerBox;
  double _getRetailPrice(String productId) => _products.firstWhere((p) => p.id == productId).retailPrice;

  int _getLoadPieces(String productId) {
    final b = int.tryParse(_loadBoxesCtrl[productId]?.text ?? '') ?? 0;
    final p = int.tryParse(_loadPiecesCtrl[productId]?.text ?? '') ?? 0;
    return (b * _getBoxSize(productId)) + p;
  }

  int _getReturnPieces(String productId) {
    final b = int.tryParse(_returnBoxesCtrl[productId]?.text ?? '') ?? 0;
    final p = int.tryParse(_returnPiecesCtrl[productId]?.text ?? '') ?? 0;
    return (b * _getBoxSize(productId)) + p;
  }

  int _getRemainingPieces(String productId) {
    final b = int.tryParse(_remBoxesCtrl[productId]?.text ?? '') ?? 0;
    final p = int.tryParse(_remPiecesCtrl[productId]?.text ?? '') ?? 0;
    return (b * _getBoxSize(productId)) + p;
  }

  double _getLoadValue(String productId) => _getLoadPieces(productId) * _getRetailPrice(productId);
  double _getReturnValue(String productId) => _getReturnPieces(productId) * _getRetailPrice(productId);
  double _getRemainingValue(String productId) => _getRemainingPieces(productId) * _getRetailPrice(productId);

  double get _totalLoadValue => _products.fold(0, (sum, p) => sum + _getLoadValue(p.id));
  double get _totalReturnValue => _products.fold(0, (sum, p) => sum + _getReturnValue(p.id));
  double get _totalRemainingValue => _products.fold(0, (sum, p) => sum + _getRemainingValue(p.id));

  double get _totalWorkerExpenses => _workers.fold(0, (sum, w) => _workerReceived[w.id] == true ? sum + w.salary : sum);
  double get _totalAdvances => _workers.fold(0, (sum, w) => sum + (double.tryParse(_advanceCtrl[w.id]?.text ?? '') ?? 0));
  double get _totalExpenses => _expenseRows.fold(0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));
  double get _totalMinorExpenses => _minorExpenseRows.fold(0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));
  double get _totalKhat => _khatRows.fold(0, (sum, row) => sum + (double.tryParse(row.amountCtrl.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المعرض — AbuLaith ERP'),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: () {}),
          IconButton(icon: const Icon(Icons.file_download), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'السحبيات والمرتجعات'),
            Tab(text: 'العمال ومصاريفهم'),
            Tab(text: 'الخرج اليومي'),
            Tab(text: 'كشف حساب المعرض'),
            Tab(text: 'قات العمال'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderBar(),
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

  Widget _buildHeaderBar() {
    return Padding(
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
    );
  }

  Widget _summaryCard(String title, double value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value.toStringAsFixed(0), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // ============ التبويب 1 ============
  Widget _buildTab1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(children: [
            _summaryCard('السحبيات', _totalLoadValue, AppTheme.errorColor),
            _summaryCard('المرتجعات', _totalReturnValue, AppTheme.successColor),
            _summaryCard('الصافي المطلوب', _totalLoadValue - _totalReturnValue, AppTheme.primaryColor),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(labelText: 'بحث عن منتج...', prefixIcon: Icon(Icons.search)),
            onChanged: _filterProducts,
          ),
          const SizedBox(height: 8),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('المنتج')),
                  DataColumn(label: Text('سحب (سلال)')),
                  DataColumn(label: Text('سحب (قطع)')),
                  DataColumn(label: Text('مرتجع (سلال)')),
                  DataColumn(label: Text('مرتجع (قطع)')),
                  DataColumn(label: Text('قيمة السحب')),
                  DataColumn(label: Text('قيمة المرتجع')),
                  DataColumn(label: Text('الصافي')),
                ],
                rows: _filteredProducts.map((p) {
                  final loadVal = _getLoadValue(p.id);
                  final retVal = _getReturnValue(p.id);
                  return DataRow(cells: [
                    DataCell(Text(p.name)),
                    DataCell(SizedBox(width: 50, child: TextField(controller: _loadBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    DataCell(SizedBox(width: 50, child: TextField(controller: _loadPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    DataCell(SizedBox(width: 50, child: TextField(controller: _returnBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    DataCell(SizedBox(width: 50, child: TextField(controller: _returnPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    DataCell(Text(loadVal.toStringAsFixed(0))),
                    DataCell(Text(retVal.toStringAsFixed(0))),
                    DataCell(Text((loadVal - retVal).toStringAsFixed(0))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerRight, child: Text('المدور عليه (البضاعة المتبقية في المعرض)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('المنتج')),
                  DataColumn(label: Text('متبقي (سلال)')),
                  DataColumn(label: Text('متبقي (قطع)')),
                  DataColumn(label: Text('قيمة البضاعة المتبقية')),
                ],
                rows: _filteredProducts.map((p) {
                  return DataRow(cells: [
                    DataCell(Text(p.name)),
                    DataCell(SizedBox(width: 60, child: TextField(controller: _remBoxesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    DataCell(SizedBox(width: 60, child: TextField(controller: _remPiecesCtrl[p.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                    DataCell(Text(_getRemainingValue(p.id).toStringAsFixed(0))),
                  ]);
                }).toList(),
              ),
            ),
          ),
          ListTile(title: const Text('إجمالي قيمة المدور عليه', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text(_totalRemainingValue.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _saveLoadsAndReturns, icon: const Icon(Icons.save), label: const Text('حفظ السحبيات والمرتجعات والمدور عليه وتحديث المخزن')),
        ],
      ),
    );
  }

  // ============ التبويب 2 ============
  Widget _buildTab2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(children: [
            _summaryCard('إجمالي الأجور', _totalWorkerExpenses, AppTheme.warningColor),
            _summaryCard('إجمالي البرانيات', _totalAdvances, AppTheme.errorColor),
          ]),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('اسم العامل')),
                  DataColumn(label: Text('المصروف اليومي')),
                  DataColumn(label: Text('استلام المصروف ✓')),
                  DataColumn(label: Text('البرانية')),
                ],
                rows: List.generate(_workers.length, (index) {
                  final w = _workers[index];
                  return DataRow(cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(w.name)),
                    DataCell(Text('${w.salary}')),
                    DataCell(Checkbox(value: _workerReceived[w.id] ?? false, onChanged: (v) => setState(() => _workerReceived[w.id] = v ?? false))),
                    DataCell(SizedBox(width: 80, child: TextField(controller: _advanceCtrl[w.id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                  ]);
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _saveWorkersAndAdvances, icon: const Icon(Icons.save), label: const Text('حفظ بيانات العمال والبرانيات')),
        ],
      ),
    );
  }

  // ============ التبويب 3 ============
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
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: TextField(controller: row.amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: TextField(controller: row.detailsCtrl, decoration: const InputDecoration(labelText: 'التفاصيل'))),
                    IconButton(icon: const Icon(Icons.delete, color: AppTheme.errorColor), onPressed: () => setState(() => _expenseRows.removeAt(i))),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(onPressed: () => setState(() => _expenseRows.add(_ExpenseRow())), icon: const Icon(Icons.add), label: const Text('إضافة خرج')),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _saveExpenses, icon: const Icon(Icons.save), label: const Text('حفظ كشف الخرج اليومي وترحيله للمدير المالي')),
        ],
      ),
    );
  }

  // ============ التبويب 4 ============
  Widget _buildTab4() {
    final showroomExpense = double.tryParse(_showroomExpenseCtrl.text) ?? 0;
    final cashReceived = double.tryParse(_cashReceivedCtrl.text) ?? 0;

    final totalDue = _prevRemaining + _totalLoadValue + showroomExpense;
    final totalCoverage = _totalReturnValue + _totalWorkerExpenses + _totalAdvances + _totalExpenses + _totalMinorExpenses + cashReceived;
    final resultAmount = totalDue - totalCoverage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Card(child: ListTile(title: const Text('1. الرصيد المرحل من اليوم السابق'), trailing: Text(_prevRemaining.toStringAsFixed(0)))),
          Card(child: ListTile(title: const Text('2. إجمالي قيمة سحبيات المعرض'), trailing: Text(_totalLoadValue.toStringAsFixed(0)))),
          Card(child: ListTile(title: const Text('3. مصروف المعرض (إدخال مدير)'), trailing: SizedBox(width: 100, child: TextField(controller: _showroomExpenseCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
          const Divider(),
          Card(color: AppTheme.primaryColor.withOpacity(0.1), child: ListTile(title: const Text('إجمالي المطلوب منه', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text(totalDue.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)))),
          const SizedBox(height: 8),
          Card(child: ListTile(title: const Text('إجمالي قيمة المرجوع (يُصدّر للمقارنة الكلية)'), trailing: Text('- ${_totalReturnValue.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('مصاريف العمال المستلمة'), trailing: Text('- ${_totalWorkerExpenses.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('إجمالي البرانيات'), trailing: Text('- ${_totalAdvances.toStringAsFixed(0)}'))),
          Card(child: ListTile(title: const Text('الخرج اليومي'), trailing: Text('- ${_totalExpenses.toStringAsFixed(0)}'))),
          
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerRight, child: Text('الكشف الصغير (حركات مالية إضافية)', style: TextStyle(fontWeight: FontWeight.bold))),
          ...List.generate(_minorExpenseRows.length, (i) {
            final r = _minorExpenseRows[i];
            return Row(
              children: [
                Expanded(flex: 2, child: TextField(controller: r.amountCtrl, decoration: const InputDecoration(hintText: 'المبلغ'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: TextField(controller: r.detailsCtrl, decoration: const InputDecoration(hintText: 'التفاصيل'))),
                IconButton(icon: const Icon(Icons.delete, color: AppTheme.errorColor), onPressed: () => setState(() => _minorExpenseRows.removeAt(i))),
              ],
            );
          }),
          TextButton.icon(onPressed: () => setState(() => _minorExpenseRows.add(_MinorExpenseRow())), icon: const Icon(Icons.add), label: const Text('إضافة بنود للكشف الصغير')),

          const Divider(),
          Card(child: ListTile(title: const Text('الواصل نقدًا'), trailing: SizedBox(width: 100, child: TextField(controller: _cashReceivedCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))))),
          
          const SizedBox(height: 12),
          Card(
            color: resultAmount == 0
                ? AppTheme.successColor.withOpacity(0.2)
                : (resultAmount > 0 ? AppTheme.errorColor.withOpacity(0.2) : Colors.blue.withOpacity(0.2)),
            child: ListTile(
              title: Text(
                resultAmount > 0 ? 'نتيجة الحساب: ضائع / عجز' : (resultAmount < 0 ? 'نتيجة الحساب: زيادة' : 'نتيجة الحساب: مطابق'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(resultAmount.abs().toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _saveDailyAccount, icon: const Icon(Icons.save), label: const Text('حفظ وإغلاق اليوم وتصدير المرجوع')),
        ],
      ),
    );
  }

  // ============ التبويب 5 ============
  Widget _buildTab5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _summaryCard('إجمالي قات العمال (مستقل لا يدخل بالرسمي)', _totalKhat, AppTheme.warningColor),
          const SizedBox(height: 8),
          ...List.generate(_khatRows.length, (i) {
            final row = _khatRows[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: row.workerId.isNotEmpty ? row.workerId : null,
                        decoration: const InputDecoration(labelText: 'العامل'),
                        items: _workers.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final selected = _workers.firstWhere((w) => w.id == val);
                            setState(() {
                              row.workerId = selected.id;
                              row.workerName = selected.name;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(controller: row.amountCtrl, decoration: const InputDecoration(labelText: 'مبلغ القات'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: TextField(controller: row.detailsCtrl, decoration: const InputDecoration(labelText: 'ملاحظات / اسم يدوي'))),
                    IconButton(icon: const Icon(Icons.delete, color: AppTheme.errorColor), onPressed: () => setState(() => _khatRows.removeAt(i))),
                  ],
                ),
              ),
            );
          }),
          TextButton.icon(onPressed: () => setState(() => _khatRows.add(_KhatRow())), icon: const Icon(Icons.add), label: const Text('إضافة صف قات')),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _saveKhat, icon: const Icon(Icons.save), label: const Text('حفظ كشف قات العمال')),
        ],
      ),
    );
  }
}
