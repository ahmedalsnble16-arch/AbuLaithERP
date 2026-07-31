import 'package:flutter/material.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class AllLoadsScreen extends StatefulWidget {
  const AllLoadsScreen({super.key});

  @override
  State<AllLoadsScreen> createState() => _AllLoadsScreenState();
}

class _AllLoadsScreenState extends State<AllLoadsScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _distributors = [];
  Map<String, Map<String, int>> _loadData = {};
  Map<String, int> _showroomData = {};
  bool _isLoading = true;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;

    final products = await db.query(DBConstants.tableProducts, where: 'deleted = 0');
    final distributors = await db.query(DBConstants.tableDistributors, where: 'deleted = 0');

    final loadMovements = await db.rawQuery('''
      SELECT sm.product_id, dl.distributor_id, COALESCE(SUM(ABS(sm.quantity)), 0) as total_loaded
      FROM ${DBConstants.tableStockMovements} sm
      INNER JOIN ${DBConstants.tableDistributorLoads} dl ON sm.reference_id = dl.id
      WHERE sm.movement_type = 'تحميل موزع' AND sm.created_at LIKE ?
      GROUP BY sm.product_id, dl.distributor_id
    ''', ['$_selectedDate%']);

    final showroomMovements = await db.rawQuery('''
      SELECT sm.product_id, COALESCE(SUM(ABS(sm.quantity)), 0) as total_to_showroom
      FROM ${DBConstants.tableStockMovements} sm
      WHERE sm.movement_type = 'تحويل' AND sm.reference_type = 'showroom' AND sm.created_at LIKE ?
      GROUP BY sm.product_id
    ''', ['$_selectedDate%']);

    final loadMap = <String, Map<String, int>>{};
    for (var row in loadMovements) {
      final productId = row['product_id'] as String;
      final distId = row['distributor_id'] as String;
      final qty = (row['total_loaded'] as num?)?.toInt() ?? 0;
      loadMap[productId] ??= {};
      loadMap[productId]![distId] = qty;
    }

    final showroomMap = <String, int>{};
    for (var row in showroomMovements) {
      showroomMap[row['product_id'] as String] = (row['total_to_showroom'] as num?)?.toInt() ?? 0;
    }

    setState(() {
      _products = products;
      _distributors = distributors;
      _loadData = loadMap;
      _showroomData = showroomMap;
      _isLoading = false;
    });
  }

  String _formatPieces(int pieces, int boxSize) {
    if (boxSize <= 0) return '$pieces';
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.$remaining';
  }

  int _getRowTotal(String productId) {
    int total = 0;
    for (var dist in _distributors) {
      total += _loadData[productId]?[dist['id']] ?? 0;
    }
    total += _showroomData[productId] ?? 0;
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جدول الحملات الكلي')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Text('التاريخ: '),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
                          controller: TextEditingController(text: _selectedDate),
                          onSubmitted: (v) {
                            _selectedDate = v;
                            fetchData();
                          },
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.search), onPressed: fetchData),
                    ],
                  ),
                ),
                Expanded(
                  child: _products.isEmpty
                      ? const Center(child: Text('لا توجد منتجات'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 12,
                              columns: [
                                const DataColumn(label: Text('المنتج')),
                                const DataColumn(label: Text('سلة')),
                                ...(_distributors.map((d) => DataColumn(label: Text(d['name'] ?? '')))),
                                const DataColumn(label: Text('المعرض')),
                                const DataColumn(label: Text('الإجمالي')),
                                const DataColumn(label: Text('سلال+قطع')),
                              ],
                              rows: _products.map((product) {
                                final productId = product['id'] as String;
                                final boxSize = product['pieces_per_box'] as int? ?? 60;
                                final rowTotal = _getRowTotal(productId);
                                return DataRow(cells: [
                                  DataCell(Text(product['name'] ?? '')),
                                  DataCell(Text('$boxSize')),
                                  ...(_distributors.map((dist) {
                                    final qty = _loadData[productId]?[dist['id']] ?? 0;
                                    return DataCell(Text(qty > 0 ? _formatPieces(qty, boxSize) : '-'));
                                  })),
                                  DataCell(Text(_showroomData[productId] != null ? _formatPieces(_showroomData[productId]!, boxSize) : '-')),
                                  DataCell(Text('$rowTotal', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(_formatPieces(rowTotal, boxSize), style: const TextStyle(fontWeight: FontWeight.bold))),
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
}
