import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_product_price_repository.dart';

class DistributorPricesScreen extends StatefulWidget {
  final String distributorId;
  final String distributorName;
  const DistributorPricesScreen({super.key, required this.distributorId, required this.distributorName});

  @override
  State<DistributorPricesScreen> createState() => _DistributorPricesScreenState();
}

class _DistributorPricesScreenState extends State<DistributorPricesScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DistributorProductPriceRepository _priceRepo = DistributorProductPriceRepository();
  List<Product> _products = [];
  Map<String, double> _prices = {};
  Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final products = await _productRepo.getAll();
    final prices = await _priceRepo.getPricesForDistributor(widget.distributorId);
    setState(() {
      _products = products.where((p) => p.active).toList();
      _prices = prices;
      for (var p in _products) {
        _controllers[p.id] = TextEditingController(
          text: (_prices[p.id] ?? p.wholesalePrice).toString(),
        );
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    for (var product in _products) {
      final price = double.tryParse(_controllers[product.id]?.text ?? '') ?? product.wholesalePrice;
      await _priceRepo.savePrice(widget.distributorId, product.id, price);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الأسعار الخاصة'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('أسعار: ${widget.distributorName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return Card(
                        child: ListTile(
                          title: Text(product.name),
                          subtitle: Text('السلة: ${product.piecesPerBox} قطعة'),
                          trailing: SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _controllers[product.id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'السعر'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ جميع الأسعار'),
                  ),
                ),
              ],
            ),
    );
  }
}
