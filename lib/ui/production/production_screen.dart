import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/stock_repository.dart';
import 'production_comparison_screen.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final StockRepository _stockRepo = StockRepository();
  List<Product> _products = [];
  
  final Map<String, TextEditingController> _goodBoxesCtrl = {};
  final Map<String, TextEditingController> _goodPiecesCtrl = {};
  final Map<String, TextEditingController> _damagedBoxesCtrl = {};
  final Map<String, TextEditingController> _damagedPiecesCtrl = {};
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await _productRepo.getAll();
    setState(() {
      _products = products.where((p) => p.active).toList();
      for (var p in _products) {
        _goodBoxesCtrl[p.id] ??= TextEditingController(text: '0');
        _goodPiecesCtrl[p.id] ??= TextEditingController(text: '0');
        _damagedBoxesCtrl[p.id] ??= TextEditingController(text: '0');
        _damagedPiecesCtrl[p.id] ??= TextEditingController(text: '0');
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    for (var c in _goodBoxesCtrl.values) { c.dispose(); }
    for (var c in _goodPiecesCtrl.values) { c.dispose(); }
    for (var c in _damagedBoxesCtrl.values) { c.dispose(); }
    for (var c in _damagedPiecesCtrl.values) { c.dispose(); }
    super.dispose();
  }

  int _goodPiecesTotal(String productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    final boxes = int.tryParse(_goodBoxesCtrl[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_goodPiecesCtrl[productId]?.text ?? '0') ?? 0;
    return (boxes * product.piecesPerBox) + pieces;
  }

  int _damagedPiecesTotal(String productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    final boxes = int.tryParse(_damagedBoxesCtrl[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_damagedPiecesCtrl[productId]?.text ?? '0') ?? 0;
    return (boxes * product.piecesPerBox) + pieces;
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    if (boxSize <= 0) return '$pieces';
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.$remaining';
  }

  Future<void> _saveProduction() async {
    final items = <Map<String, dynamic>>[];
    for (var product in _products) {
      final good = _goodPiecesTotal(product.id);
      final damaged = _damagedPiecesTotal(product.id);
      if (good > 0 || damaged > 0) {
        items.add({
          'productId': product.id,
          'goodPieces': good,
          'damagedPieces': damaged,
          'totalPieces': good + damaged,
        });
      }
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد كميات مدخلة'), backgroundColor: AppTheme.warningColor),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = await DatabaseHelper().database;
      final now = DatabaseHelper.now;
      final batchPrefix = 'PROD-${DateTime.now().millisecondsSinceEpoch}';

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final productId = item['productId'] as String;
        final good = item['goodPieces'] as int;
        final damaged = item['damagedPieces'] as int;
        final total = item['totalPieces'] as int;
        // رقم فريد لكل منتج داخل الدفعة
        final batchNumber = '$batchPrefix-$i';

        await db.insert(DBConstants.tableProductionBatches, {
          'id': const Uuid().v4(),
          'production_number': batchNumber,
          'product_id': productId,
          'production_date': DateTime.now().toIso8601String().substring(0, 10),
          'expected_pieces': total,
          'good_pieces': good,
          'damaged_pieces': damaged,
          'lost_pieces': 0,
          'hits': 0,
          'pieces_per_hit': 0,
          'good_boxes': 0,
          'damaged_boxes': 0,
          'production_cost': 0,
          'status': 'معتمدة',
          'created_at': now,
          'updated_at': now,
          'sync_status': 'Pending',
          'deleted': 0,
        });

        await _stockRepo.addStock(productId, good);

        await db.insert(DBConstants.tableStockMovements, {
          'id': const Uuid().v4(),
          'product_id': productId,
          'movement_type': 'إنتاج',
          'quantity': good,
          'reference_id': batchNumber,
          'reference_type': 'production',
          'notes': 'إنتاج دفعة $batchNumber',
          'created_at': now,
          'sync_status': 'Pending',
        });
      }

      for (var p in _products) {
        _goodBoxesCtrl[p.id]?.text = '0';
        _goodPiecesCtrl[p.id]?.text = '0';
        _damagedBoxesCtrl[p.id]?.text = '0';
        _damagedPiecesCtrl[p.id]?.text = '0';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإنتاج وإضافة السليم للمخزن'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============ سجل الإنتاج ============
  Future<List<Map<String, dynamic>>> _fetchProductionHistory() async {
    final db = await DatabaseHelper().database;
    return await db.rawQuery('''
      SELECT pb.*, p.name as product_name, p.pieces_per_box
      FROM ${DBConstants.tableProductionBatches} pb
      INNER JOIN ${DBConstants.tableProducts} p ON pb.product_id = p.id
      WHERE pb.deleted = 0
      ORDER BY pb.production_date DESC, pb.created_at DESC
      LIMIT 100
    ''');
  }

  Widget _buildProductionHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchProductionHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final batches = snapshot.data ?? [];
        if (batches.isEmpty) {
          return const Center(child: Text('لا توجد دفعات إنتاج'));
        }
        return ListView.builder(
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final batch = batches[index];
            final boxSize = batch['pieces_per_box'] as int? ?? 60;
            final good = batch['good_pieces'] as int? ?? 0;
            final damaged = batch['damaged_pieces'] as int? ?? 0;
            final total = good + damaged;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.deepOrange,
                  child: Icon(Icons.factory, color: Colors.white),
                ),
                title: Text(batch['product_name'] ?? ''),
                subtitle: Text(
                  '${batch['production_date']} | سليم: ${_piecesToDisplay(good, boxSize)} | تالف: ${_piecesToDisplay(damaged, boxSize)}',
                ),
                trailing: Text(
                  _piecesToDisplay(total, boxSize),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإنتاج'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 13),
            tabs: [
              Tab(text: 'تسجيل الإنتاج'),
              Tab(text: 'سجل الإنتاج'),
              Tab(text: 'مقارنة وتحليل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildProductionEntryTab(),
            _buildProductionHistoryTab(),
            const ProductionComparisonScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionEntryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📦 تسجيل الإنتاج اليومي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 8,
                      columns: const [
                        DataColumn(label: Text('المنتج')),
                        DataColumn(label: Text('سلة')),
                        DataColumn(label: Text('إنتاج (سلال)')),
                        DataColumn(label: Text('إنتاج (قطع)')),
                        DataColumn(label: Text('تالف (سلال)')),
                        DataColumn(label: Text('تالف (قطع)')),
                        DataColumn(label: Text('الإجمالي')),
                      ],
                      rows: _products.map((product) {
                        final id = product.id;
                        final boxSize = product.piecesPerBox;
                        final good = _goodPiecesTotal(id);
                        final damaged = _damagedPiecesTotal(id);
                        final total = good + damaged;
                        return DataRow(cells: [
                          DataCell(Text(product.name)),
                          DataCell(Text('$boxSize')),
                          DataCell(SizedBox(width: 60, child: TextField(
                            controller: _goodBoxesCtrl[id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: InputBorder.none),
                            onChanged: (_) => setState(() {}),
                          ))),
                          DataCell(SizedBox(width: 60, child: TextField(
                            controller: _goodPiecesCtrl[id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: InputBorder.none),
                            onChanged: (_) => setState(() {}),
                          ))),
                          DataCell(SizedBox(width: 60, child: TextField(
                            controller: _damagedBoxesCtrl[id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: InputBorder.none),
                            onChanged: (_) => setState(() {}),
                          ))),
                          DataCell(SizedBox(width: 60, child: TextField(
                            controller: _damagedPiecesCtrl[id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(border: InputBorder.none),
                            onChanged: (_) => setState(() {}),
                          ))),
                          DataCell(Text(
                            _piecesToDisplay(total, boxSize),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProduction,
              icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ الإنتاج وإضافة السليم للمخزن'),
            ),
          ),
        ],
      ),
    );
  }
}
