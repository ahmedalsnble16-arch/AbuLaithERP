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
  Map<String, dynamic> _comparison = {};
  bool _isLoading = true;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;

    // جلب المنتجات
    final products = await db.query(DBConstants.tableProducts, where: 'deleted = 0');

    // جلب إنتاج اليوم
    final production = await db.rawQuery('''
      SELECT product_id, COALESCE(SUM(good_pieces), 0) as total_produced
      FROM ${DBConstants.tableProductionBatches}
      WHERE production_date = ? AND deleted = 0
      GROUP BY product_id
    ''', [_selectedDate]);

    // جلب مخزون الإنتاج الحالي
    final stock = await db.query(DBConstants.tableStock);

    // جلب حملات الموزعين لليوم
    final loads = await db.rawQuery('''
      SELECT sm.product_id, COALESCE(SUM(ABS(sm.quantity)), 0) as total_loaded
      FROM ${DBConstants.tableStockMovements} sm
      WHERE sm.movement_type = 'تحميل موزع' AND sm.created_at LIKE ?
      GROUP BY sm.product_id
    ''', ['$_selectedDate%']);

    setState(() {
      _products = products;
      _comparison = {
        'production': {for (var p in production) p['product_id']: p['total_produced']},
        'stock': {for (var s in stock) s['product_id']: s['quantity_pieces']},
        'loads': {for (var l in loads) l['product_id']: l['total_loaded']},
      };
      _isLoading = false;
    });
  }

  int _getValue(Map<String, dynamic> map, String productId) {
    return (map[productId] as num?)?.toInt() ?? 0;
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    if (boxSize <= 0) return '$pieces';
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.$remaining';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف المقارنة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('لا توجد منتجات'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // محدد التاريخ
                      Row(
                        children: [
                          const Text('التاريخ: '),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
                              controller: TextEditingController(text: _selectedDate),
                              onChanged: (v) {
                                _selectedDate = v;
                                _loadData();
                              },
                            ),
                          ),
                          ElevatedButton(onPressed: _loadData, child: const Text('إجراء المقارنة')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // جدول المقارنة
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('المنتج')),
                            DataColumn(label: Text('إنتاج اليوم')),
                            DataColumn(label: Text('المخزن الحالي')),
                            DataColumn(label: Text('تحميل الموزعين')),
                            DataColumn(label: Text('المتاح - الخارج')),
                            DataColumn(label: Text('الحالة')),
                          ],
                          rows: _products.map((product) {
                            final productId = product['id'] as String;
                            final boxSize = product['pieces_per_box'] as int? ?? 60;
                            final produced = _getValue(_comparison['production'] ?? {}, productId);
                            final stockQty = _getValue(_comparison['stock'] ?? {}, productId);
                            final loaded = _getValue(_comparison['loads'] ?? {}, productId);
                            final diff = stockQty - loaded;
                            final color = diff < 0 ? AppTheme.errorColor : AppTheme.successColor;
                            return DataRow(cells: [
                              DataCell(Text(product['name'] ?? '')),
                              DataCell(Text(_piecesToDisplay(produced, boxSize))),
                              DataCell(Text(_piecesToDisplay(stockQty, boxSize))),
                              DataCell(Text(_piecesToDisplay(loaded, boxSize))),
                              DataCell(Text(_piecesToDisplay(diff, boxSize), style: TextStyle(color: color, fontWeight: FontWeight.bold))),
                              DataCell(diff < 0
                                  ? const Text('نقص', style: TextStyle(color: AppTheme.errorColor))
                                  : const Text('متوفر', style: TextStyle(color: AppTheme.successColor))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
