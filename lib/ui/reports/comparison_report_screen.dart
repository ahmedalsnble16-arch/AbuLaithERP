import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ComparisonReportScreen extends StatefulWidget {
  const ComparisonReportScreen({super.key});

  @override
  State<ComparisonReportScreen> createState() => _ComparisonReportScreenState();
}

class _ComparisonReportScreenState extends State<ComparisonReportScreen> {
  List<Map<String, dynamic>> _products = [];
  Map<String, int> _yesterdayRemaining = {};
  Map<String, int> _todayProduction = {};
  Map<String, int> _showroomOut = {};
  Map<String, Map<String, int>> _distributorOutByDistributor = {};
  Map<String, int> _showroomReturn = {};
  Map<String, Map<String, int>> _distributorReturnsByDistributor = {};
  List<Map<String, dynamic>> _distributors = [];
  Map<String, int> _currentStock = {};
  bool _isLoading = true;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);
  bool _hasRunComparison = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterProduct = 'all';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final db = await DatabaseHelper().database;
    final products = await db.query(DBConstants.tableProducts, where: 'deleted = 0');
    final distributors = await db.query(DBConstants.tableDistributors, where: 'deleted = 0');
    setState(() {
      _products = products;
      _distributors = distributors;
      _isLoading = false;
    });
  }

  Future<void> _runComparison() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final yesterdayDate = DateTime.parse(_selectedDate)
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    try {
      final yesterdayComparison = await db.rawQuery('''
        SELECT product_id, COALESCE(remaining_pieces, 0) as remaining_pieces
        FROM ${DBConstants.tableProductionCompare}
        WHERE compare_date = ?
      ''', [yesterdayDate]);
      final map = <String, int>{};
      for (var row in yesterdayComparison) {
        map[row['product_id'] as String] = (row['remaining_pieces'] as num?)?.toInt() ?? 0;
      }
      _yesterdayRemaining = map;
    } catch (e) {
      _yesterdayRemaining = {};
    }

    // إنتاج اليوم
    {
      final production = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(good_pieces), 0) as total
        FROM ${DBConstants.tableProductionBatches}
        WHERE production_date = ? AND deleted = 0
        GROUP BY product_id
      ''', [_selectedDate]);
      final map = <String, int>{};
      for (var row in production) {
        map[row['product_id'] as String] = (row['total'] as num?)?.toInt() ?? 0;
      }
      _todayProduction = map;
    }

    // سحب المعرض
    {
      final showroomOut = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'تحويل' AND reference_type = 'showroom' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$_selectedDate%']);
      final map = <String, int>{};
      for (var row in showroomOut) {
        map[row['product_id'] as String] = (row['total'] as num?)?.toInt() ?? 0;
      }
      _showroomOut = map;
    }

    // تحميل الموزعين (كل موزع على حدة)
    {
      final distributorOut = await db.rawQuery('''
        SELECT product_id, distributor_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'تحميل موزع' AND created_at LIKE ?
        GROUP BY product_id, distributor_id
      ''', ['$_selectedDate%']);
      final map = <String, Map<String, int>>{};
      for (var row in distributorOut) {
        final productId = row['product_id'] as String;
        final distId = row['distributor_id'] as String? ?? 'unknown';
        final qty = (row['total'] as num?)?.toInt() ?? 0;
        map[productId] ??= {};
        map[productId]![distId] = qty;
      }
      _distributorOutByDistributor = map;
    }

    // مرتجع المعرض
    {
      final showroomReturn = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'مرتجع' AND reference_type = 'showroom' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$_selectedDate%']);
      final map = <String, int>{};
      for (var row in showroomReturn) {
        map[row['product_id'] as String] = (row['total'] as num?)?.toInt() ?? 0;
      }
      _showroomReturn = map;
    }

    // مرتجعات الموزعين (كل موزع على حدة)
    {
      final distReturns = await db.rawQuery('''
        SELECT product_id, distributor_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'مرتجع' AND reference_type = 'distributor' AND created_at LIKE ?
        GROUP BY product_id, distributor_id
      ''', ['$_selectedDate%']);
      final map = <String, Map<String, int>>{};
      for (var row in distReturns) {
        final productId = row['product_id'] as String;
        final distId = row['distributor_id'] as String? ?? 'unknown';
        final qty = (row['total'] as num?)?.toInt() ?? 0;
        map[productId] ??= {};
        map[productId]![distId] = qty;
      }
      _distributorReturnsByDistributor = map;
    }

    // المخزون الحالي
    {
      final currentStock = await db.query(DBConstants.tableStock);
      final map = <String, int>{};
      for (var row in currentStock) {
        map[row['product_id'] as String] = (row['quantity_pieces'] as num?)?.toInt() ?? 0;
      }
      _currentStock = map;
    }

    setState(() {
      _hasRunComparison = true;
      _isLoading = false;
    });
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    if (boxSize <= 0) return '$pieces';
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.$remaining';
  }

  int _displayToPieces(String display, int boxSize) {
    final parts = display.split('.');
    final boxes = int.tryParse(parts[0]) ?? 0;
    final pieces = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return (boxes * boxSize) + pieces;
  }

  int _getBoxSize(String productId) {
    final product = _products.firstWhere((p) => p['id'] == productId,
        orElse: () => {'pieces_per_box': 60});
    return product['pieces_per_box'] as int? ?? 60;
  }

  void _updateActualStock(String productId, String newValue) {
    final boxSize = _getBoxSize(productId);
    final pieces = _displayToPieces(newValue, boxSize);
    setState(() {
      _currentStock[productId] = pieces;
    });
  }

  void _showProductDetail(Map<String, dynamic> product) {
    final id = product['id'] as String;
    final boxSize = _getBoxSize(id);
    final yesterday = _yesterdayRemaining[id] ?? 0;
    final prod = _todayProduction[id] ?? 0;
    final showOut = _showroomOut[id] ?? 0;
    int distOut = 0;
    _distributorOutByDistributor[id]?.forEach((_, qty) { distOut += qty; });
    final showReturn = _showroomReturn[id] ?? 0;
    int distReturn = 0;
    _distributorReturnsByDistributor[id]?.forEach((_, qty) { distReturn += qty; });
    final actual = _currentStock[id] ?? 0;
    final available = yesterday + prod + showReturn + distReturn;
    final outgoing = showOut + distOut;
    final theoretical = available - outgoing;
    final diff = actual - theoretical;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفاصيل: ${product['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('متبقي أمس', _piecesToDisplay(yesterday, boxSize), '$yesterday قطعة'),
              _detailRow('إنتاج اليوم', _piecesToDisplay(prod, boxSize), '$prod قطعة'),
              _detailRow('مرجوع المعرض', _piecesToDisplay(showReturn, boxSize), '$showReturn قطعة'),
              _detailRow('مرجوع الموزعين', _piecesToDisplay(distReturn, boxSize), '$distReturn قطعة'),
              const Divider(),
              _detailRow('إجمالي المتاح', _piecesToDisplay(available, boxSize), '$available قطعة'),
              const SizedBox(height: 8),
              _detailRow('سحب المعرض', _piecesToDisplay(showOut, boxSize), '$showOut قطعة'),
              _detailRow('تحميل الموزعين', _piecesToDisplay(distOut, boxSize), '$distOut قطعة'),
              const Divider(),
              _detailRow('إجمالي الخارج', _piecesToDisplay(outgoing, boxSize), '$outgoing قطعة'),
              const SizedBox(height: 8),
              _detailRow('الرصيد النظري', _piecesToDisplay(theoretical, boxSize), '$theoretical قطعة'),
              _detailRow('الرصيد الفعلي', _piecesToDisplay(actual, boxSize), '$actual قطعة'),
              const Divider(),
              _detailRow('الفرق', '${diff >= 0 ? "+" : ""}$diff قطعة',
                  _piecesToDisplay(diff.abs(), boxSize),
                  color: diff == 0 ? AppTheme.textSecondaryColor : (diff > 0 ? AppTheme.successColor : AppTheme.errorColor)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String display, String pieces, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('$display ($pieces)', style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    return _products.where((p) {
      if (_filterProduct != 'all' && p['id'] != _filterProduct) return false;
      if (_searchQuery.isNotEmpty) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف المقارنة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('⚖️ كشف المقارنة',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            onPressed: _runComparison,
                            icon: const Icon(Icons.search, color: Colors.amber),
                            label: const Text('🔍 إجراء المقارنة'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('التاريخ: '),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
                          controller: TextEditingController(text: _selectedDate),
                          onChanged: (v) => _selectedDate = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '🔍 بحث فوري عن منتج...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 16),
                  if (_hasRunComparison) ...[
                    // قسم الصادر مع أعمدة الموزعين الفرعية
                    _buildOutgoingSection(),
                    const SizedBox(height: 16),
                    _buildIncomingSection(),
                    const SizedBox(height: 16),
                    _buildSection('📊 نتيجة المقارنة',
                        columns: const [
                          'المنتج',
                          'المتاح',
                          'الخارج',
                          'النظري',
                          'الفعلي',
                          'الفرق',
                          'الحالة'
                        ],
                        rows: _buildResultRows()),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Icon(Icons.compare_arrows,
                                size: 64, color: AppTheme.textSecondaryColor),
                            const SizedBox(height: 16),
                            const Text('اضغط "إجراء المقارنة" لعرض النتائج'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _runComparison,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('إجراء المقارنة الآن'),
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

  Widget _buildOutgoingSection() {
    final distributorColumns = _distributors.map((d) => d['name'] ?? '').toList();
    final allColumns = ['المنتج', 'المعرض', ...distributorColumns, 'الإجمالي'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📤 حركة البضاعة (الصادرة)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                columns: allColumns.map((c) => DataColumn(label: Text(c))).toList(),
                rows: _getFilteredProducts().map((product) {
                  final id = product['id'] as String;
                  final boxSize = _getBoxSize(id);
                  final showOut = _showroomOut[id] ?? 0;
                  int totalDistOut = 0;
                  final cells = <DataCell>[
                    DataCell(Text('${product['name']} ($boxSize)')),
                    DataCell(Text(_piecesToDisplay(showOut, boxSize))),
                  ];
                  for (var dist in _distributors) {
                    final distId = dist['id'] as String;
                    final qty = _distributorOutByDistributor[id]?[distId] ?? 0;
                    totalDistOut += qty;
                    cells.add(DataCell(Text(_piecesToDisplay(qty, boxSize))));
                  }
                  cells.add(DataCell(Text(_piecesToDisplay(showOut + totalDistOut, boxSize),
                      style: const TextStyle(fontWeight: FontWeight.bold))));
                  return DataRow(
                    cells: cells,
                    onSelectChanged: (_) => _showProductDetail(product),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingSection() {
    final distributorColumns = _distributors.map((d) => d['name'] ?? '').toList();
    final allColumns = ['المنتج', 'متبقي أمس', 'إنتاج اليوم', 'مرجوع المعرض', ...distributorColumns, 'الإجمالي'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📥 مصادر البضاعة (الواردة)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                columns: allColumns.map((c) => DataColumn(label: Text(c))).toList(),
                rows: _getFilteredProducts().map((product) {
                  final id = product['id'] as String;
                  final boxSize = _getBoxSize(id);
                  final yesterday = _yesterdayRemaining[id] ?? 0;
                  final prod = _todayProduction[id] ?? 0;
                  final showReturn = _showroomReturn[id] ?? 0;
                  int totalDistReturn = 0;
                  final cells = <DataCell>[
                    DataCell(Text('${product['name']} ($boxSize)')),
                    DataCell(Text(_piecesToDisplay(yesterday, boxSize))),
                    DataCell(Text(_piecesToDisplay(prod, boxSize))),
                    DataCell(Text(_piecesToDisplay(showReturn, boxSize))),
                  ];
                  for (var dist in _distributors) {
                    final distId = dist['id'] as String;
                    final qty = _distributorReturnsByDistributor[id]?[distId] ?? 0;
                    totalDistReturn += qty;
                    cells.add(DataCell(Text(_piecesToDisplay(qty, boxSize))));
                  }
                  cells.add(DataCell(Text(_piecesToDisplay(yesterday + prod + showReturn + totalDistReturn, boxSize),
                      style: const TextStyle(fontWeight: FontWeight.bold))));
                  return DataRow(
                    cells: cells,
                    onSelectChanged: (_) => _showProductDetail(product),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildResultRows() {
    return _getFilteredProducts().map((product) {
      final id = product['id'] as String;
      final boxSize = _getBoxSize(id);
      final yesterday = _yesterdayRemaining[id] ?? 0;
      final prod = _todayProduction[id] ?? 0;
      final showOut = _showroomOut[id] ?? 0;
      int distOut = 0;
      _distributorOutByDistributor[id]?.forEach((_, qty) { distOut += qty; });
      final showReturn = _showroomReturn[id] ?? 0;
      int distReturn = 0;
      _distributorReturnsByDistributor[id]?.forEach((_, qty) { distReturn += qty; });
      final actual = _currentStock[id] ?? 0;
      final available = yesterday + prod + showReturn + distReturn;
      final outgoing = showOut + distOut;
      final theoretical = available - outgoing;
      final diff = actual - theoretical;

      Color color;
      String status;
      if (diff > 0) {
        color = AppTheme.successColor;
        status = 'زيادة ${_piecesToDisplay(diff, boxSize)}';
      } else if (diff < 0) {
        color = AppTheme.errorColor;
        status = 'نقص ${_piecesToDisplay(diff.abs(), boxSize)}';
      } else {
        color = AppTheme.textSecondaryColor;
        status = 'متطابق';
      }

      return DataRow(
        cells: [
          DataCell(Text(product['name'] ?? '')),
          DataCell(Text(_piecesToDisplay(available, boxSize))),
          DataCell(Text(_piecesToDisplay(outgoing, boxSize))),
          DataCell(Text(_piecesToDisplay(theoretical, boxSize))),
          DataCell(
            SizedBox(
              width: 80,
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  border: OutlineInputBorder(),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
                controller: TextEditingController(text: _piecesToDisplay(actual, boxSize)),
                onChanged: (v) => _updateActualStock(id, v),
              ),
            ),
          ),
          DataCell(Text(_piecesToDisplay(diff, boxSize),
              style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: diff == 0 ? Colors.grey.shade100 : color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status, style: TextStyle(color: color, fontSize: 11)),
          )),
        ],
        onSelectChanged: (_) => _showProductDetail(product),
      );
    }).toList();
  }

  Widget _buildSection(String title,
      {required List<String> columns, required List<DataRow> rows}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
