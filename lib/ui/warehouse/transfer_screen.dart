import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/stock_repository.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final StockRepository _stockRepo = StockRepository();
  List<Product> _products = [];
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
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
      _isLoading = false;
    });
  }

  Future<void> _transfer() async {
    if (_selectedProduct == null) return;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كمية صحيحة')));
      return;
    }

    final success = await _stockRepo.deductStock(_selectedProduct!.id, qty);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الكمية غير متوفرة')));
      return;
    }

    final db = await DatabaseHelper().database;
    final showroomStock = await db.query('showroom_stock', where: 'product_id = ?', whereArgs: [_selectedProduct!.id]);
    if (showroomStock.isEmpty) {
      await db.insert('showroom_stock', {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'product_id': _selectedProduct!.id,
        'quantity': qty,
        'retail_price': _selectedProduct!.retailPrice,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      final current = showroomStock.first['quantity'] as int? ?? 0;
      await db.update('showroom_stock', {'quantity': current + qty, 'updated_at': DateTime.now().toIso8601String()}, where: 'product_id = ?', whereArgs: [_selectedProduct!.id]);
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحويل إلى المعرض')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل للمعرض')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<Product>(
                    value: _selectedProduct,
                    decoration: const InputDecoration(labelText: 'المنتج'),
                    items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (p) => setState(() => _selectedProduct = p),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'الكمية (قطع)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _transfer, child: const Text('تحويل')),
                ],
              ),
            ),
    );
  }
}
