import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/sale_repository.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final SaleRepository _saleRepo = SaleRepository();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  String _paymentType = 'نقدي';
  List<Product> _products = [];
  List<Map<String, dynamic>> _cart = [];
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

  void _addToCart(Product product) {
    setState(() {
      int index = _cart.indexWhere((e) => e['productId'] == product.id);
      if (index >= 0) {
        _cart[index]['quantity'] += 1;
        _cart[index]['total'] = _cart[index]['quantity'] * _cart[index]['unitPrice'];
      } else {
        _cart.add({
          'productId': product.id,
          'name': product.name,
          'quantity': 1,
          'unitPrice': product.retailPrice,
          'total': product.retailPrice,
        });
      }
    });
  }

  double get _totalAmount => _cart.fold(0, (sum, item) => sum + (item['total'] as double));
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _grandTotal => _totalAmount - _discount;

  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجات للفاتورة'), backgroundColor: AppTheme.warningColor),
      );
      return;
    }

    try {
      await _saleRepo.createSale(
        customerId: null,
        customerName: _customerNameController.text.trim().isNotEmpty
            ? _customerNameController.text.trim()
            : 'عميل نقدي',
        items: _cart.map((e) => {
          'productId': e['productId'],
          'quantity': e['quantity'],
          'unitPrice': e['unitPrice'],
        }).toList(),
        discount: _discount,
        paymentType: _paymentType,
        createdBy: 'admin',
        deviceId: 'mobile',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم البيع بنجاح'), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة بيع')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(controller: _customerNameController, decoration: const InputDecoration(labelText: 'اسم العميل (اختياري)')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(controller: _discountController, decoration: const InputDecoration(labelText: 'الخصم'), keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Text('طريقة الدفع: '),
                    DropdownButton<String>(
                      value: _paymentType,
                      items: const [
                        DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                        DropdownMenuItem(value: 'آجل', child: Text('آجل')),
                      ],
                      onChanged: (val) => setState(() => _paymentType = val!),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('الإجمالي: $_totalAmount | بعد الخصم: $_grandTotal'),
                ),
                ElevatedButton(onPressed: _saveSale, child: const Text('إتمام البيع')),
                const Divider(),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.2),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return Card(
                        child: InkWell(
                          onTap: () => _addToCart(product),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(product.name, textAlign: TextAlign.center),
                              Text('${product.retailPrice}', style: const TextStyle(color: AppTheme.successColor)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
