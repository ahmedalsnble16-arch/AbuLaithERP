import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class AllLoadsScreen extends StatefulWidget {
  const AllLoadsScreen({super.key});

  @override
  State<AllLoadsScreen> createState() => _AllLoadsScreenState();
}

class _AllLoadsScreenState extends State<AllLoadsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _distributors = [];
  Map<String, Map<String, int>> _loadDataMap = {};
  Map<String, int> _showroomData = {};

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String? _filterDistributorId;
  String? _filterProductId;
  String _searchQuery = '';
  bool _isLoading = true;

  String? _sortColumn;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;

      _products = await db.query(DBConstants.tableProducts,
          where: 'active = 1 AND deleted = 0', orderBy: 'name ASC');

      _distributors = await db.query(DBConstants.tableDistributors,
          where: 'active = 1 AND deleted = 0', orderBy: 'name ASC');

      final fromStr = _fromDate.toIso8601String().substring(0, 10);
      final toStr = _toDate.toIso8601String().substring(0, 10);

      final distLoads = await db.rawQuery('''
        SELECT dli.product_id, dl.distributor_id, SUM(dli.quantity) as total
        FROM ${DBConstants.tableDistributorLoadItems} dli
        JOIN ${DBConstants.tableDistributorLoads} dl ON dli.load_id = dl.id
        WHERE dl.load_date BETWEEN ? AND ?
        GROUP BY dli.product_id, dl.distributor_id
      ''', [fromStr, toStr]);

      _loadDataMap.clear();
      for (var row in distLoads) {
        final pId = row['product_id'] as String;
        final dId = row['distributor_id'] as String;
        final qty = (row['total'] as num?)?.toInt() ?? 0;
        _loadDataMap[pId] ??= {};
        _loadDataMap[pId]![dId] = qty;
      }

      final showroomLoads = await db.rawQuery('''
        SELECT product_id, SUM(load_total_pieces) as total
        FROM ${DBConstants.tableShowroomDailyEntries}
        WHERE business_date BETWEEN ? AND ?
        GROUP BY product_id
      ''', [fromStr, toStr]);

      _showroomData.clear();
      for (var row in showroomLoads) {
        _showroomData[row['product_id'] as String] =
            (row['total'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading loads data: $e');
    }
    setState(() => _isLoading = false);
  }

  int _getDistributorLoad(String productId, String distributorId) {
    return _loadDataMap[productId]?[distributorId] ?? 0;
  }

  int _getShowroomLoad(String productId) {
    return _showroomData[productId] ?? 0;
  }

  int _getRowTotal(String productId) {
    int total = _getShowroomLoad(productId);
    for (var d in _distributors) {
      total += _getDistributorLoad(productId, d['id'] as String);
    }
    return total;
  }

  String _formatPieces(int totalPieces, int boxSize) {
    if (boxSize <= 0) return totalPieces.toString();
    final boxes = totalPieces ~/ boxSize;
    final pieces = totalPieces % boxSize;
    return '$boxes.$pieces';
  }

  int _getBoxSize(String productId) {
    final p = _products.firstWhere((e) => e['id'] == productId,
        orElse: () => {'pieces_per_box': 60});
    return p['pieces_per_box'] as int? ?? 60;
  }

  Future<void> _showLoadDetails(String productId, String distributorId) async {
    final db = await _dbHelper.database;
    final fromStr = _fromDate.toIso8601String().substring(0, 10);
    final toStr = _toDate.toIso8601String().substring(0, 10);

    final details = await db.rawQuery('''
      SELECT dli.quantity, dl.load_date, dl.created_at
      FROM ${DBConstants.tableDistributorLoadItems} dli
      JOIN ${DBConstants.tableDistributorLoads} dl ON dli.load_id = dl.id
      WHERE dli.product_id = ? AND dl.distributor_id = ?
        AND dl.load_date BETWEEN ? AND ?
      ORDER BY dl.load_date DESC, dl.created_at DESC
    ''', [productId, distributorId, fromStr, toStr]);

    if (!mounted) return;

    final productName = _products.firstWhere((e) => e['id'] == productId,
        orElse: () => {'name': ''})['name'] ?? '';
    final distName = _distributors.firstWhere((e) => e['id'] == distributorId,
        orElse: () => {'name': ''})['name'] ?? '';
    final boxSize = _getBoxSize(productId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفاصيل تحميل $productName إلى $distName'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الفترة: $fromStr - $toStr'),
              const Divider(),
              if (details.isEmpty)
                const Text('لا توجد حركات تحميل في هذه الفترة')
              else
                ...details.map((d) => ListTile(
                      dense: true,
                      title: Text(
                          'الكمية: ${_formatPieces(d['quantity'] as int? ?? 0, boxSize)} (${d['quantity']} قطعة)'),
                      subtitle: Text(
                          'التاريخ: ${d['load_date']} - الوقت: ${(d['created_at'] as String? ?? '').substring(11, 19)}'),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _showShowroomDetails(String productId) async {
    final db = await _dbHelper.database;
    final fromStr = _fromDate.toIso8601String().substring(0, 10);
    final toStr = _toDate.toIso8601String().substring(0, 10);

    final details = await db.query(
      DBConstants.tableShowroomDailyEntries,
      where: 'product_id = ? AND business_date BETWEEN ? AND ?',
      whereArgs: [productId, fromStr, toStr],
      orderBy: 'business_date DESC',
    );

    if (!mounted) return;

    final productName = _products.firstWhere((e) => e['id'] == productId,
        orElse: () => {'name': ''})['name'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفاصيل تحميل المعرض - $productName'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الفترة: $fromStr - $toStr'),
              const Divider(),
              if (details.isEmpty)
                const Text('لا توجد تحميلات للمعرض في هذه الفترة')
              else
                ...details.map((d) {
                  final loadBoxes = d['load_boxes'] as int? ?? 0;
                  final loadPieces = d['load_pieces'] as int? ?? 0;
                  final totalPieces = d['load_total_pieces'] as int? ?? 0;
                  return ListTile(
                    dense: true,
                    title: Text('$loadBoxes سلة + $loadPieces قطعة (إجمالي $totalPieces قطعة)'),
                    subtitle: Text('التاريخ: ${d['business_date']}'),
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var list = _products;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((p) =>
              (p['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_filterProductId != null) {
      list = list.where((p) => p['id'] == _filterProductId).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredDistributors {
    if (_filterDistributorId != null) {
      return _distributors.where((d) => d['id'] == _filterDistributorId).toList();
    }
    return _distributors;
  }

  void _sort<T>(List<Map<String, dynamic>> list, String column, bool ascending, T Function(Map<String, dynamic>) getter) {
    list.sort((a, b) {
      final aVal = getter(a);
      final bVal = getter(b);
      return ascending ? Comparable.compare(aVal as Comparable, bVal as Comparable)
          : Comparable.compare(bVal as Comparable, aVal as Comparable);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الحملات الكلي'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.print), onPressed: () {}),
          IconButton(icon: const Icon(Icons.file_download), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: _buildTable(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).primaryColor.withAlpha(10),
      child: Column(
        children: [
          Row(
            children: [
              _quickDateButton('اليوم', DateTime.now(), DateTime.now()),
              const SizedBox(width: 8),
              _quickDateButton('أمس', DateTime.now().subtract(const Duration(days: 1)), DateTime.now().subtract(const Duration(days: 1))),
              const SizedBox(width: 8),
              _quickDateButton('آخر 7 أيام', DateTime.now().subtract(const Duration(days: 6)), DateTime.now()),
              const SizedBox(width: 8),
              _quickDateButton('الشهر', DateTime(DateTime.now().year, DateTime.now().month, 1), DateTime.now()),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                    '${_fromDate.toLocal().toString().substring(0, 10)} - ${_toDate.toLocal().toString().substring(0, 10)}'),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                  );
                  if (picked != null) {
                    setState(() {
                      _fromDate = picked.start;
                      _toDate = picked.end;
                    });
                    _loadData();
                  }
                },
              ),
              DropdownButton<String?>(
                hint: const Text('كل الموزعين'),
                value: _filterDistributorId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الموزعين')),
                  ..._distributors.map((d) => DropdownMenuItem(
                      value: d['id'] as String, child: Text(d['name'] ?? ''))),
                ],
                onChanged: (val) => setState(() => _filterDistributorId = val),
              ),
              DropdownButton<String?>(
                hint: const Text('كل المنتجات'),
                value: _filterProductId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل المنتجات')),
                  ..._products.map((p) => DropdownMenuItem(
                      value: p['id'] as String, child: Text(p['name'] ?? ''))),
                ],
                onChanged: (val) => setState(() => _filterProductId = val),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: const InputDecoration(
                      hintText: 'بحث...', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickDateButton(String label, DateTime start, DateTime end) {
    return TextButton(
      onPressed: () {
        setState(() {
          _fromDate = start;
          _toDate = end;
        });
        _loadData();
      },
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildTable() {
    final filteredProducts = _filteredProducts;
    final filteredDistributors = _filteredDistributors;

    final Map<String, int> columnTotals = {};
    int grandTotal = 0;

    if (_sortColumn != null) {
      switch (_sortColumn) {
        case 'name':
          _sort(filteredProducts, 'name', _sortAscending, (p) => p['name'] ?? '');
          break;
        case 'showroom':
          _sort(filteredProducts, 'showroom', _sortAscending, (p) => _getShowroomLoad(p['id']));
          break;
        case 'total':
          _sort(filteredProducts, 'total', _sortAscending, (p) => _getRowTotal(p['id']));
          break;
        default:
          final distId = _sortColumn;
          _sort(filteredProducts, distId!, _sortAscending, (p) => _getDistributorLoad(p['id'], distId));
      }
    }

    final List<DataRow> rows = [];
    for (var product in filteredProducts) {
      final productId = product['id'] as String;
      final boxSize = _getBoxSize(productId);
      final cells = <DataCell>[
        DataCell(Text(product['name'] ?? '')),
      ];

      for (var d in filteredDistributors) {
        final dId = d['id'] as String;
        final qty = _getDistributorLoad(productId, dId);
        columnTotals[dId] = (columnTotals[dId] ?? 0) + qty;
        cells.add(DataCell(InkWell(
          onTap: () => _showLoadDetails(productId, dId),
          child: Text(qty > 0 ? _formatPieces(qty, boxSize) : '-'),
        )));
      }

      final showroomQty = _getShowroomLoad(productId);
      columnTotals['showroom'] = (columnTotals['showroom'] ?? 0) + showroomQty;
      cells.add(DataCell(InkWell(
        onTap: () => _showShowroomDetails(productId),
        child: Text(showroomQty > 0 ? _formatPieces(showroomQty, boxSize) : '-'),
      )));

      final total = _getRowTotal(productId);
      grandTotal += total;
      cells.add(DataCell(Text(_formatPieces(total, boxSize),
          style: const TextStyle(fontWeight: FontWeight.bold))));

      rows.add(DataRow(cells: cells));
    }

    if (filteredProducts.isNotEmpty) {
      final firstProductId = filteredProducts.first['id'] as String;
      final totalCells = <DataCell>[
        const DataCell(Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
      ];
      for (var d in filteredDistributors) {
        final dId = d['id'] as String;
        final boxSize = _getBoxSize(firstProductId);
        totalCells.add(DataCell(Text(
            _formatPieces(columnTotals[dId] ?? 0, boxSize),
            style: const TextStyle(fontWeight: FontWeight.bold))));
      }
      totalCells.add(DataCell(Text(
          _formatPieces(columnTotals['showroom'] ?? 0, _getBoxSize(firstProductId)),
          style: const TextStyle(fontWeight: FontWeight.bold))));
      totalCells.add(DataCell(Text(
          _formatPieces(grandTotal, _getBoxSize(firstProductId)),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))));

      rows.add(DataRow(
        cells: totalCells,
        color: MaterialStateProperty.all(Theme.of(context).primaryColor.withAlpha(15)),
      ));
    }

    final columns = <DataColumn>[
      DataColumn(
        label: const Text('المنتج'),
        onSort: (columnIndex, ascending) {
          setState(() {
            _sortColumn = 'name';
            _sortAscending = ascending;
          });
        },
      ),
      ...filteredDistributors.map((d) => DataColumn(
            label: Text(d['name'] ?? ''),
            onSort: (columnIndex, ascending) {
              setState(() {
                _sortColumn = d['id'] as String;
                _sortAscending = ascending;
              });
            },
          )),
      DataColumn(
        label: const Text('المعرض'),
        onSort: (columnIndex, ascending) {
          setState(() {
            _sortColumn = 'showroom';
            _sortAscending = ascending;
          });
        },
      ),
      DataColumn(
        label: const Text('الإجمالي'),
        onSort: (columnIndex, ascending) {
          setState(() {
            _sortColumn = 'total';
            _sortAscending = ascending;
          });
        },
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns,
        rows: rows,
        columnSpacing: 12,
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 40,
        showBottomBorder: true,
      ),
    );
  }
}
