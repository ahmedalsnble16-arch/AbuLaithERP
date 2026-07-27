import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_repository.dart';

class DistributorSettleScreen extends StatefulWidget {
  final String distributorId;
  final String distributorName;
  const DistributorSettleScreen({super.key, required this.distributorId, required this.distributorName});

  @override
  State<DistributorSettleScreen> createState() => _DistributorSettleScreenState();
}

class _DistributorSettleScreenState extends State<DistributorSettleScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DistributorRepository _distRepo = DistributorRepository();
  List<Product> _products = [];
  Map<String, Map<String, int>> _data = {};
  double _collectedCash = 0;
  String? _loadId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _productRepo.getAll();
    final openLoads = await _distRepo.getOpenLoads(widget.distributorId);
    setState(() {
      _products = products.where((p) => p.active).toList();
      if (openLoads.isNotEmpty) _loadId = openLoads.first.id;
      for (var p in _products) {
        _data[p.id] = {'sold': 0, 'returned': 0, 'damaged': 0};
      }
      _isLoading = false;
    });
  }

  Future<void> _settle() async {
    if (_loadId == null) return;
    final items = _data.entries.map((e) => {
      'productId': e.key,
      'sold': e.value['sold'] ?? 0,
      'returned': e.value['returned'] ?? 0,
      'damaged': e.value['damaged'] ?? 0,
      'unitPrice': _products.firstWhere((p) => p.id == e.key).wholesalePrice,
    }).toList();

    await _distRepo.settleDistributor(
      distributorId: widget.distributorId,
      loadId: _loadId!,
      items: items,
      collectedCash: _collectedCash,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت التصفية'), backgroundColor: AppTheme.successColor));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تصفية: ${widget.distributorName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final d = _data[product.id] ?? {'sold': 0, 'returned': 0, 'damaged': 0};
                      return Card(
                        child: Column(
                          children: [
                            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildField('مباع', d['sold'] ?? 0, (v) => setState(() => _data[product.id]!['sold'] = v)),
                                _buildField('مرتجع', d['returned'] ?? 0, (v) => setState(() => _data[product.id]!['returned'] = v)),
                                _buildField('تالف', d['damaged'] ?? 0, (v) => setState(() => _data[product.id]!['damaged'] = v)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'النقدية المحصلة'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _collectedCash = double.tryParse(v) ?? 0,
                ),
                ElevatedButton(onPressed: _settle, child: const Text('تصفية')),
              ],
            ),
    );
  }

  Widget _buildField(String label, int value, Function(int) onChanged) {
    return Column(
      children: [
        Text(label),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => onChanged(value > 0 ? value - 1 : 0)),
            Text('$value'),
            IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }
}
