import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_product_price_repository.dart';
import '../../data/repositories/distributor_damage_repository.dart' as damageRepo;

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
  final damageRepo.DistributorDamageRepository _damageRepo = damageRepo.DistributorDamageRepository();

  List<Product> _products = [];
  Map<String, double> _prices = {};
  Map<String, TextEditingController> _productControllers = {};

  // أسعار التالف
  Map<String, double> _damagePrices = {};
  final TextEditingController _smallPriceCtrl = TextEditingController();
  final TextEditingController _largePriceCtrl = TextEditingController();
  final TextEditingController _tamerPriceCtrl = TextEditingController();

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
    final damagePrices = await _damageRepo.getDamagePrices(widget.distributorId);

    setState(() {
      _products = products.where((p) => p.active).toList();
      _prices = prices;
      _damagePrices = damagePrices;

      for (var p in _products) {
        _productControllers[p.id] = TextEditingController(
          text: (_prices[p.id] ?? p.wholesalePrice).toString(),
        );
      }
      _smallPriceCtrl.text = (_damagePrices['صغير'] ?? 0).toString();
      _largePriceCtrl.text = (_damagePrices['كبير'] ?? 0).toString();
      _tamerPriceCtrl.text = (_damagePrices['تمرية كبير'] ?? 0).toString();

      _isLoading = false;
    });
  }

  Future<void> _save() async {
    for (var p in _products) {
      final price = double.tryParse(_productControllers[p.id]?.text ?? '') ?? p.wholesalePrice;
      await _priceRepo.savePrice(widget.distributorId, p.id, price);
    }
    // حفظ أسعار التالف
    await _damageRepo.saveDamagePrice(widget.distributorId, 'صغير', double.tryParse(_smallPriceCtrl.text) ?? 0);
    await _damageRepo.saveDamagePrice(widget.distributorId, 'كبير', double.tryParse(_largePriceCtrl.text) ?? 0);
    await _damageRepo.saveDamagePrice(widget.distributorId, 'تمرية كبير', double.tryParse(_tamerPriceCtrl.text) ?? 0);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الأسعار'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  @override
  void dispose() {
    for (var c in _productControllers.values) { c.dispose(); }
    _smallPriceCtrl.dispose();
    _largePriceCtrl.dispose();
    _tamerPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('أسعار: ${widget.distributorName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('أسعار المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ..._products.map((p) => Card(
                        child: ListTile(
                          title: Text(p.name),
                          subtitle: Text('السلة: ${p.piecesPerBox} قطعة'),
                          trailing: SizedBox(
                            width: 100,
                            child: TextField(
                              controller: _productControllers[p.id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'السعر'),
                            ),
                          ),
                        ),
                      )),
                  const Divider(height: 32),
                  const Text('أسعار التالف (للقطعة)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildDamagePriceRow('صغير', _smallPriceCtrl),
                  _buildDamagePriceRow('كبير', _largePriceCtrl),
                  _buildDamagePriceRow('تمرية كبير', _tamerPriceCtrl),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ جميع الأسعار'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDamagePriceRow(String label, TextEditingController ctrl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            SizedBox(
              width: 100,
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سعر القطعة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
