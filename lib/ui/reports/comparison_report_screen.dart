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
  Map<String, int> _distributorOut = {};
  Map<String, int> _showroomReturn = {};
  Map<String, int> _distributorReturn = {};
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
    setState(() {
      _products = products;
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
        final key = row['product_id']?.toString();
        if (key != null) {
          map[key] = (row['remaining_pieces'] as num?)?.toInt() ?? 0;
        }
      }
      _yesterdayRemaining = map;
    } catch (e) {
      _yesterdayRemaining = {};
    }

    // Production today
    {
      final production = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(good_pieces), 0) as total
        FROM ${DBConstants.tableProductionBatches}
        WHERE production_date = ? AND deleted = 0
        GROUP BY product_id
      ''', [_selectedDate]);
      final map = <String, int>{};
      for (var row in production) {
        final key = row['product_id']?.toString();
        if (key != null) {
          map[key] = (row['total'] as num?)?.toInt() ?? 0;
        }
      }
      _todayProduction = map;
    }

    // showroom out
    {
      final showroomOut = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'تحويل' AND reference_type = 'showroom' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$_selectedDate%']);
      final map = <String, int>{};
      for (var row in showroomOut) {
        final key = row['product_id']?.toString();
        if (key != null) {
          map[key] = (row['total'] as num?)?.toInt() ?? 0;
        }
      }
      _showroomOut = map;
    }

    // distributor out
    {
      final distributorOut = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'تحميل موزع' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$_selectedDate%']);
      final map = <String, int>{};
      for (var row in distributorOut) {
        final key = row['product_id']?.toString();
        if (key != null) {
          map[key] = (row['total'] as num?)?.toInt() ?? 0;
        }
      }
      _distributorOut = map;
    }

    // showroom return
    {
      final showroomReturn = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'مرتجع' AND reference_type = 'showroom' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$_selectedDate%']);
      final map = <String, int>{};
      for (var row in showroomReturn) {
        final key = row['product_id']?.toString();
        if (key != null) {
          map[key] = (row['total'] as num?)?.toInt() ?? 0;
        }
      }
      _showroomReturn = map;
    }

    // distributor return
    {
      final distributorReturn = await db.rawQuery('''
        SELECT product_id, COALESCE(SUM(ABS(quantity)), 0) as total
        FROM ${DBConstants.tableStockMovements}
        WHERE movement_type = 'مرتجع' AND reference_type = 'distributor' AND created_at LIKE ?
        GROUP BY product_id
      ''', ['$_selectedDate%']);
      final map = <String, int>{};
      for (var row in distributorReturn) {
        final key = row['product_id']?.toString();
        if (key != null) {
          map[key] = (row['total'] as num?)?.toInt() ?? 0;
        }
      }
      _distributorReturn = map;
    }

    // current stock
    {
      final currentStock = await db.query(DBConstants.tableStock);
      final map = <String, int>{};
      for (var row in currentStock) {
        final key = row['product_id']?.toString();
        if (key != null) {
          map[key] = (row['quantity_pieces'] as num?)?.toInt() ?? 0;
        }
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
    final distOut = _distributorOut[id] ?? 0;
    final showReturn = _showroomReturn[id] ?? 0;
    final distReturn = _distributorReturn[id] ?? 0;
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
                    _buildSection('📤 حركة البضاعة (الصادرة)',
                        columns: const [
                          'المنتج',
                          'المعرض',
                          'المتبقي بالمخزن',
                          'تحميل الموزعين',
                          'الإجمالي'
                        ],
                        rows: _buildOutgoingRows()),
                    const SizedBox(height: 16),
                    _buildSection('📥 مصادر البضاعة (الواردة)',
                        columns: const [
                          'المنتج',
                          'متبقي أمس',
                          'إنتاج اليوم',
                          'مرجوع المعرض',
                          'مرجوع الموزعين',
                          'الإجمالي'
                        ],
                        rows: _buildIncomingRows()),
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

  List<DataRow> _buildOutgoingRows() {
    return _getFilteredProducts().map((product) {
      final id = product['id'] as String;
      final boxSize = _getBoxSize(id);
      final showOut = _showroomOut[id] ?? 0;
      final remaining = _currentStock[id] ?? 0;
      final distOut = _distributorOut[id] ?? 0;
      final total = showOut + remaining + distOut;
      return DataRow(
        cells: [
          DataCell(Text('${product['name']} ($boxSize)')),
          DataCell(Text(_piecesToDisplay(showOut, boxSize))),
          DataCell(Text(_piecesToDisplay(remaining, boxSize))),
          DataCell(Text(_piecesToDisplay(distOut, boxSize))),
          DataCell(Text(_piecesToDisplay(total, boxSize),
              style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
        onSelectChanged: (_) => _showProductDetail(product),
      );
    }).toList();
  }

  List<DataRow> _buildIncomingRows() {
    return _getFilteredProducts().map((product) {
      final id = product['id'] as String;
      final boxSize = _getBoxSize(id);
      final yesterday = _yesterdayRemaining[id] ?? 0;
      final prod = _todayProduction[id] ?? 0;
      final showReturn = _showroomReturn[id] ?? 0;
      final distReturn = _distributorReturn[id] ?? 0;
      final total = yesterday + prod + showReturn + distReturn;
      return DataRow(
        cells: [
          DataCell(Text('${product['name']} ($boxSize)')),
          DataCell(Text(_piecesToDisplay(yesterday, boxSize))),
          DataCell(Text(_piecesToDisplay(prod, boxSize))),
          DataCell(Text(_piecesToDisplay(showReturn, boxSize))),
          DataCell(Text(_piecesToDisplay(distReturn, boxSize))),
          DataCell(Text(_piecesToDisplay(total, boxSize),
              style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
        onSelectChanged: (_) => _showProductDetail(product),
      );
    }).toList();
  }

  List<DataRow> _buildResultRows() {
    return _getFilteredProducts().map((product) {
      final id = product['id'] as String;
      final boxSize = _getBoxSize(id);
      final yesterday = _yesterdayRemaining[id] ?? 0;
      final prod = _todayProduction[id] ?? 0;
      final showOut = _showroomOut[id] ?? 0;
      final distOut = _distributorOut[id] ?? 0;
      final showReturn = _showroomReturn[id] ?? 0;
      final distReturn = _distributorReturn[id] ?? 0;
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
                columns: columns
                    .map((c) => DataColumn(label: Text(c)))
                    .toList(),
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
