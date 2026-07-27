import 'package:flutter/material.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../core/database/database_helper.dart';

class DistributorReturnsScreen extends StatefulWidget {
  final String distributorId;
  final String distributorName;
  const DistributorReturnsScreen({super.key, required this.distributorId, required this.distributorName});

  @override
  State<DistributorReturnsScreen> createState() => _DistributorReturnsScreenState();
}

class _DistributorReturnsScreenState extends State<DistributorReturnsScreen> {
  final ProductRepository _productRepo = ProductRepository();
  List<Product> _products = [];
  final Map<String, int> _returned = {};
  final Map<String, int> _damaged = {};
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
      for (var p in _products) {
        _returned[p.id] = 0;
        _damaged[p.id] = 0;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveReturn() async {
    final db = await DatabaseHelper().database;
    for (var product in _products) {
      final returned = _returned[product.id] ?? 0;
      final damaged = _damaged[product.id] ?? 0;
      if (returned > 0 || damaged > 0) {
        await db.insert('distributor_returns', {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'distributor_id': widget.distributorId,
          'product_id': product.id,
          'returned': returned,
          'damaged': damaged,
          'settlement_date': DateTime.now().toIso8601String().substring(0, 10),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل المرتجع')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مرتجع: ${widget.distributorName}')),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(child: ListView.builder(itemCount: _products.length, itemBuilder: (context, index) {
                final product = _products[index];
                return Card(child: Column(children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _quantityField('مرتجع صالح', _returned[product.id] ?? 0, (v) => setState(() => _returned[product.id] = v)),
                    _quantityField('تالف', _damaged[product.id] ?? 0, (v) => setState(() => _damaged[product.id] = v)),
                  ]),
                ]));
              })),
              ElevatedButton.icon(onPressed: _saveReturn, icon: const Icon(Icons.save), label: const Text('حفظ المرتجع')),
            ]),
    );
  }

  Widget _quantityField(String label, int value, Function(int) onChange) {
    return Column(children: [
      Text(label),
      Row(children: [
        IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => onChange(value > 0 ? value - 1 : 0)),
        Text('$value'), IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => onChange(value + 1)),
      ]),
    ]);
  }
}
