import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/daily_remaining_repository.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DailyRemainingRepository _dailyRepo = DailyRemainingRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Product> _products = [];
  Map<String, int> _stockData = {};
  Map<String, int> _todayProduction = {};
  Map<String, int> _showroomReturns = {};
  Map<String, int> _showroomTransfers = {};
  Map<String, int> _distributorTransfers = {};
  Map<String, Map<String, int>> _distributorReturns = {};
  Map<String, int> _dailyRemaining = {};
  List<String> _distributorNames = [];

  Map<String, TextEditingController> _remainingBoxesCtrl = {};
  Map<String, TextEditingController> _remainingPiecesCtrl = {};

  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final date = _selectedDate;

      // 1. المنتجات النشطة
      final allProducts = await _productRepo.getAll();
      final activeProducts = allProducts.where((p) => p.active).toList();

      // 2. المخزون الحالي (من جدول stock)
      final stockList = await db.query(DBConstants.tableStock);
      final stockMap = <String, int>{};
      for (var s in stockList) {
        stockMap[s['product_id'] as String] = (s['quantity_pieces'] as num?)?.toInt() ?? 0;
      }

      // 3. إنتاج اليوم (good_pieces فقط)
      final production = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(good_pieces), 0) as total
        FROM ${DBConstants.tableProductionBatches}
        WHERE production_date = ? AND deleted = 0
        GROUP BY product_id
      ''', [date]);
      final prodMap = <String, int>{};
      for (var p in production) {
        prodMap[p['product_id'] as String] = (p['total'] as num?)?.toInt() ?? 0;
      }

      // 4. مرجوع المعرض (من stock_movements)
      final showroomReturns = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'مرتجع' AND reference_type = 'showroom' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$date%']);
      final showroomReturnMap = <String, int>{};
      for (var r in showroomReturns) {
        showroomReturnMap[r['product_id'] as String] = (r['total'] as num?)?.toInt() ?? 0;
      }

      // 5. تحويلات للمعرض (تخصم من المخزون)
      final showroomTransfers = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'تحويل' AND reference_type = 'showroom' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$date%']);
      final showroomTransferMap = <String, int>{};
      for (var t in showroomTransfers) {
        showroomTransferMap[t['product_id'] as String] = (t['total'] as num?)?.toInt() ?? 0;
      }

      // 6. تحميلات للموزعين (تخصم من المخزون)
      final distributorTransfers = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'تحميل موزع' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$date%']);
      final distTransferMap = <String, int>{};
      for (var t in distributorTransfers) {
        distTransferMap[t['product_id'] as String] = (t['total'] as num?)?.toInt() ?? 0;
      }

      // 7. مرجوع الموزعين (من جدول distributor_load_returns)
      final distReturns = await db.rawQuery('''
        SELECT dr.product_id, d.name as distributor_name, COALESCE(SUM(dr.total_pieces), 0) as total
        FROM ${DBConstants.tableDistributorLoadReturns} dr
        INNER JOIN ${DBConstants.tableDistributors} d ON dr.distributor_id = d.id
        WHERE dr.return_date = ?
        GROUP BY dr.product_id, d.name
      ''', [date]);
      final distReturnMap = <String, Map<String, int>>{};
      final distNames = <String>{};
      for (var r in distReturns) {
        final productId = r['product_id'] as String;
        final name = r['distributor_name'] as String;
        final total = (r['total'] as num?)?.toInt() ?? 0;
        distReturnMap[productId] ??= {};
        distReturnMap[productId]![name] = total;
        distNames.add(name);
      }

      // 8. المتبقي اليوم (من daily_remaining)
      final dailyRemaining = await _dailyRepo.getByDate(date);

      setState(() {
        _products = activeProducts;
        _stockData = stockMap;
        _todayProduction = prodMap;
        _showroomReturns = showroomReturnMap;
        _showroomTransfers = showroomTransferMap;
        _distributorTransfers = distTransferMap;
        _distributorReturns = distReturnMap;
        _distributorNames = distNames.toList();
        _dailyRemaining = dailyRemaining;

        for (var p in activeProducts) {
          final remaining = dailyRemaining[p.id] ?? 0;
          final boxes = remaining ~/ p.piecesPerBox;
          final pieces = remaining % p.piecesPerBox;
          _remainingBoxesCtrl[p.id] = TextEditingController(text: boxes.toString());
          _remainingPiecesCtrl[p.id] = TextEditingController(text: pieces.toString());
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  int _getRemainingPieces(String productId) {
    final boxes = int.tryParse(_remainingBoxesCtrl[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_remainingPiecesCtrl[productId]?.text ?? '0') ?? 0;
    final product = _products.firstWhere((p) => p.id == productId);
    return (boxes * product.piecesPerBox) + pieces;
  }

  int _totalDistributorReturns(String productId) {
    int total = 0;
    if (_distributorReturns.containsKey(productId)) {
      for (var qty in _distributorReturns[productId]!.values) {
        total += qty;
      }
    }
    return total;
  }

  int _totalStock(String productId) {
    final remaining = _getRemainingPieces(productId);
    final production = _todayProduction[productId] ?? 0;
    final showroomReturn = _showroomReturns[productId] ?? 0;
    final distReturn = _totalDistributorReturns(productId);
    final showroomTransfer = _showroomTransfers[productId] ?? 0;
    final distTransfer = _distributorTransfers[productId] ?? 0;
    return remaining + production + showroomReturn + distReturn - showroomTransfer - distTransfer;
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    if (boxSize <= 0) return '$pieces ق';
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    if (boxes == 0) return '$remaining ق';
    if (remaining == 0) return '$boxes س';
    return '$boxes س + $remaining ق';
  }

  Future<void> _saveRemaining() async {
    setState(() => _isSaving = true);
    try {
      for (var product in _products) {
        final total = _getRemainingPieces(product.id);
        final boxes = int.tryParse(_remainingBoxesCtrl[product.id]?.text ?? '0') ?? 0;
        final pieces = int.tryParse(_remainingPiecesCtrl[product.id]?.text ?? '0') ?? 0;
        await _dailyRepo.saveRemaining(
          productId: product.id,
          quantity: total,
          boxes: boxes,
          pieces: pieces,
          date: _selectedDate,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ المتبقي اليوم'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (var c in _remainingBoxesCtrl.values) { c.dispose(); }
    for (var c in _remainingPiecesCtrl.values) { c.dispose(); }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مخزن الإنتاج'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'حفظ المتبقي',
            onPressed: _isSaving ? null : _saveRemaining,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // محدد التاريخ
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Text('التاريخ: '),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'YYYY-MM-DD', isDense: true),
                          controller: TextEditingController(text: _selectedDate),
                          onSubmitted: (v) {
                            _selectedDate = v;
                            _loadAllData();
                          },
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          _selectedDate = date.toIso8601String().substring(0, 10);
                          _loadAllData();
                        }
                      }),
                    ],
                  ),
                ),
                // شريط البحث
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '🔍 بحث عن منتج...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(height: 8),
                // الجدول
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 8,
                        columns: [
                          const DataColumn(label: Text('المنتج')),
                          const DataColumn(label: Text('سلة')),
                          const DataColumn(label: Text('المتبقي اليوم')),
                          const DataColumn(label: Text('إنتاج اليوم')),
                          const DataColumn(label: Text('مرجوع المعرض')),
                          // أعمدة الموزعين
                          if (_distributorNames.isNotEmpty)
                            DataColumn(label: _buildDistributorHeader()),
                          ...(_distributorNames.map((name) => DataColumn(label: Text(name)))),
                          if (_distributorNames.isNotEmpty)
                            const DataColumn(label: Text('إجمالي مرجوع الموزعين')),
                          const DataColumn(label: Text('إجمالي المخزون')),
                        ],
                        rows: _filteredProducts.map((product) {
                          final id = product.id;
                          final boxSize = product.piecesPerBox;
                          final prod = _todayProduction[id] ?? 0;
                          final showroom = _showroomReturns[id] ?? 0;
                          final distTotal = _totalDistributorReturns(id);
                          final total = _totalStock(id);

                          return DataRow(cells: [
                            DataCell(Text(product.name)),
                            DataCell(Text('$boxSize')),
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: TextField(
                                        controller: _remainingBoxesCtrl[id],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration.collapsed(hintText: 'س'),
                                      ),
                                    ),
                                    const Text('س '),
                                    SizedBox(
                                      width: 40,
                                      child: TextField(
                                        controller: _remainingPiecesCtrl[id],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration.collapsed(hintText: 'ق'),
                                      ),
                                    ),
                                    const Text('ق'),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(_piecesToDisplay(prod, boxSize))),
                            DataCell(Text(_piecesToDisplay(showroom, boxSize))),
                            if (_distributorNames.isNotEmpty)
                              const DataCell(Text('')),
                            ...(_distributorNames.map((name) {
                              final qty = _distributorReturns[id]?[name] ?? 0;
                              return DataCell(Text(_piecesToDisplay(qty, boxSize)));
                            })),
                            if (_distributorNames.isNotEmpty)
                              DataCell(Text(_piecesToDisplay(distTotal, boxSize))),
                            DataCell(Text(
                              _piecesToDisplay(total, boxSize),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            )),
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

  Widget _buildDistributorHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('مرجوع الموزعين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
