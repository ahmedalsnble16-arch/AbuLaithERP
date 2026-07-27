import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductRepository _productRepo = ProductRepository();
  List<Product> _products = [];
  Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _productRepo.getAll();
    setState(() {
      _products = products.where((p) => p.active).toList();
      for (var p in _products) { _controllers[p.id] = TextEditingController(); }
      _isLoading = false;
    });
  }

  Future<void> _saveInventory() async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    for (var product in _products) {
      final actualQty = int.tryParse(_controllers[product.id]?.text ?? '') ?? 0;
      final stockList = await db.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [product.id]);
      final systemQty = stockList.isNotEmpty ? (stockList.first['quantity_pieces'] as int? ?? 0) : 0;
      final difference = actualQty - systemQty;
      if (difference != 0) {
        await db.insert(DBConstants.tableInventoryCounts, {
          'id': const Uuid().v4(), 'product_id': product.id, 'system_quantity': systemQty,
          'actual_quantity': actualQty, 'difference': difference, 'status': 'مسودة',
          'count_date': DateTime.now().toIso8601String().substring(0, 10), 'created_at': now, 'updated_at': now,
        });
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الجرد'), backgroundColor: AppTheme.successColor));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جرد المخزون')),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(child: ListView.builder(itemCount: _products.length, itemBuilder: (context, index) {
                final product = _products[index];
                return Card(child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [
                  Expanded(flex: 2, child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: TextField(controller: _controllers[product.id], decoration: const InputDecoration(labelText: 'الكمية الفعلية'), keyboardType: TextInputType.number)),
                ])));
              })),
              Padding(padding: const EdgeInsets.all(16), child: ElevatedButton.icon(onPressed: _saveInventory, icon: const Icon(Icons.save), label: const Text('حفظ الجرد'))),
            ]),
    );
  }
}
