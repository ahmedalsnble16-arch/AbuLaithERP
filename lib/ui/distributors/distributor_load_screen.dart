import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/models/distributor.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_repository.dart';

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
  
  List<Product> _products = [];
  List<Distributor> _distributors = [];
  String? _selectedDistributorId;
  String? _selectedDistributorName;
  
  // نظام السلال والقطع
  Map<String, TextEditingController> _boxesControllers = {};
  Map<String, TextEditingController> _piecesControllers = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final products = await _productRepo.getAll();
    final distributors = await _distRepo.getAll();
    
    setState(() {
      _products = products.where((p) => p.active).toList();
      _distributors = distributors;
      
      if (widget.distributorId.isNotEmpty) {
        _selectedDistributorId = widget.distributorId;
        _selectedDistributorName = widget.distributorName;
      }
      
      for (var p in _products) {
        _boxesControllers[p.id] = TextEditingController(text: '0');
        _piecesControllers[p.id] = TextEditingController(text: '0');
      }
      _isLoading = false;
    });
  }

  int _totalPieces(String productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    final boxes = int.tryParse(_boxesControllers[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_piecesControllers[productId]?.text ?? '0') ?? 0;
    return (boxes * product.piecesPerBox) + pieces;
  }

  String _formatDisplay(String productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    final total = _totalPieces(productId);
    final boxes = total ~/ product.piecesPerBox;
    final remaining = total % product.piecesPerBox;
    return '$boxes.$remaining';
  }

  Future<void> _saveLoad() async {
    if (_selectedDistributorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر موزعاً'), backgroundColor: AppTheme.warningColor),
      );
      return;
    }

    final items = _products
        .where((p) => _totalPieces(p.id) > 0)
        .map((p) => {
              'productId': p.id,
              'quantity': _totalPieces(p.id),
            })
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف كميات'), backgroundColor: AppTheme.warningColor),
      );
      return;
    }

    await _distRepo.createLoad(
      distributorId: _selectedDistributorId!,
      items: items,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التحميل'), backgroundColor: AppTheme.successColor),
      );
      Navigator.pop(context);
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
      appBar: AppBar(title: Text('تحميل: ${_selectedDistributorName ?? widget.distributorName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // اختيار الموزع (إذا لم يتم التحديد مسبقاً)
                if (widget.distributorId.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDistributorId,
                      decoration: const InputDecoration(labelText: 'اختر الموزع'),
                      items: _distributors
                          .map((d) => DropdownMenuItem<String>(value: d.id, child: Text(d.name)))
                          .toList(),
                      onChanged: (val) {
                        final dist = _distributors.firstWhere((d) => d.id == val);
                        setState(() {
                          _selectedDistributorId = dist.id;
                          _selectedDistributorName = dist.name;
                        });
                      },
                    ),
                  ),
                // جدول المنتجات مع السلال والقطع
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final total = _totalPieces(product.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('السلة: ${product.piecesPerBox} قطعة | السعر: ${product.wholesalePrice} ر.ي'),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _boxesControllers[product.id],
                                      decoration: const InputDecoration(labelText: 'عدد السلال'),
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
                              Text(
                                'الكمية: ${_formatDisplay(product.id)} ($total قطعة)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'قيمة التحميل: ${(total * product.wholesalePrice).toStringAsFixed(0)} ر.ي',
                                style: const TextStyle(color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // زر الحفظ
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: _saveLoad,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ التحميل'),
                  ),
                ),
              ],
            ),
    );
  }
}
