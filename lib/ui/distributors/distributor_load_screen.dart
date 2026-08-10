import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/models/distributor.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_repository.dart';
import '../../data/repositories/distributor_product_price_repository.dart';

class DistributorLoadScreen extends StatefulWidget {
  final String distributorId;
  final String distributorName;
  const DistributorLoadScreen({
    super.key,
    required this.distributorId,
    required this.distributorName,
  });

  @override
  State<DistributorLoadScreen> createState() => _DistributorLoadScreenState();
}

class _DistributorLoadScreenState extends State<DistributorLoadScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DistributorRepository _distRepo = DistributorRepository();
  final DistributorProductPriceRepository _priceRepo = DistributorProductPriceRepository();
  
  List<Product> _products = [];
  Map<String, double> _prices = {};
  
  final Map<String, TextEditingController> _boxesControllers = {};
  final Map<String, TextEditingController> _piecesControllers = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepo.getAll();
      final prices = await _priceRepo.getPricesForDistributor(widget.distributorId);
      
      setState(() {
        _products = products.where((p) => p.active).toList();
        _prices = prices;
        
        for (var p in _products) {
          _boxesControllers[p.id] = TextEditingController(text: '0');
          _piecesControllers[p.id] = TextEditingController(text: '0');
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _parsePieces(String productId) {
    final p = _products.firstWhere((x) => x.id == productId);
    final boxes = int.tryParse(_boxesControllers[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_piecesControllers[productId]?.text ?? '0') ?? 0;
    return (boxes * p.piecesPerBox) + pieces;
  }

  double _getPrice(String productId) =>
      _prices[productId] ?? _products.firstWhere((x) => x.id == productId).wholesalePrice;

  Future<void> _saveLoad() async {
    final items = <Map<String, dynamic>>[];
    for (var p in _products) {
      final qty = _parsePieces(p.id);
      if (qty > 0) {
        items.add({
          'productId': p.id,
          'quantity': qty,
          'unitPrice': _getPrice(p.id),
        });
      }
    }

    if (items.isEmpty) {
      _showMsg('أدخل كميات للتحميل أولاً');
      return;
    }

    try {
      await _distRepo.createLoad(
        distributorId: widget.distributorId,
        items: items,
      );
      _showMsg('تم حفظ التحميل بنجاح', success: true);
      Navigator.pop(context);
    } catch (e) {
      _showMsg('خطأ أثناء الحفظ: $e', success: false);
    }
  }

  void _showMsg(String msg, {bool success = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ));
    }
  }

  @override
  void dispose() {
    for (var c in _boxesControllers.values) { c.dispose(); }
    for (var c in _piecesControllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تحميل: ${widget.distributorName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final total = _parsePieces(product.id);
                      final value = total * _getPrice(product.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('السلة: ${product.piecesPerBox} قطعة | السعر: ${_getPrice(product.id)} ر.ي'),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _boxesControllers[product.id],
                                      decoration: const InputDecoration(labelText: 'سلال'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _piecesControllers[product.id],
                                      decoration: InputDecoration(labelText: 'قطع (< ${product.piecesPerBox})'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('قيمة التحميل: ${value.toStringAsFixed(0)} ر.ي',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _saveLoad,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ التحميل'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                  ),
                ),
              ],
            ),
    );
  }
}
