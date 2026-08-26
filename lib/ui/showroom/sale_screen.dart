import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/sale_repository.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final SaleRepository _saleRepo = SaleRepository();

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Map<String, dynamic>> _cart = [];

  Customer? _selectedCustomer;
  bool _showCustomerDropdown = false;

  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _paymentType = 'نقدي';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepo.getAll();
      final customers = await _customerRepo.getAll();
      setState(() {
        _products = products.where((p) => p.active).toList();
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ============ السلة ============
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

  void _increaseQuantity(int index) {
    setState(() {
      _cart[index]['quantity'] += 1;
      _cart[index]['total'] = _cart[index]['quantity'] * _cart[index]['unitPrice'];
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (_cart[index]['quantity'] > 1) {
        _cart[index]['quantity'] -= 1;
        _cart[index]['total'] = _cart[index]['quantity'] * _cart[index]['unitPrice'];
      } else {
        _cart.removeAt(index);
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  // ============ الحسابات ============
  double get _totalAmount => _cart.fold(0.0, (sum, item) => sum + (item['total'] as double));
  double get _discount => double.tryParse(_discountController.text) ?? 0;
  double get _grandTotal => (_totalAmount - _discount) > 0 ? (_totalAmount - _discount) : 0;

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ============ حفظ الفاتورة ============
  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      _showMessage('أضف منتجات للفاتورة أولاً', success: false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _saleRepo.createSale(
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name ?? 'عميل نقدي',
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

      // تنظيف
      setState(() {
        _cart.clear();
        _discountController.text = '0';
        _selectedCustomer = null;
        _showCustomerDropdown = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الفاتورة وإضافتها للخزنة'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool success = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة بيع من المعرض')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ============ السلة ============
                Expanded(
                  flex: 3,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('🛒 سلة المشتريات', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: _cart.isEmpty
                              ? const Center(child: Text('اضغط على منتج لإضافته للسلة'))
                              : ListView.builder(
                                  itemCount: _cart.length,
                                  itemBuilder: (context, index) {
                                    final item = _cart[index];
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: AppTheme.primaryColor.withAlpha(20),
                                        child: const Icon(Icons.inventory, color: AppTheme.primaryColor, size: 18),
                                      ),
                                      title: Text(item['name']),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle, color: AppTheme.errorColor, size: 20),
                                            onPressed: () => _decreaseQuantity(index),
                                          ),
                                          Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle, color: AppTheme.successColor, size: 20),
                                            onPressed: () => _increaseQuantity(index),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: AppTheme.errorColor, size: 18),
                                            onPressed: () => _removeFromCart(index),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ============ الإجماليات ============
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [const Text('الإجمالي'), Text('${_totalAmount.toStringAsFixed(2)}')],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(child: Text('الخصم')),
                            Expanded(
                              child: TextField(
                                controller: _discountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الصافي', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successColor, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ============ العميل والدفع ============
                Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _showCustomerDropdown = !_showCustomerDropdown),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_selectedCustomer?.name ?? 'اختر العميل (اختياري)'),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                        if (_showCustomerDropdown)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  title: const Text('عميل نقدي'),
                                  onTap: () => setState(() {
                                    _selectedCustomer = null;
                                    _showCustomerDropdown = false;
                                  }),
                                ),
                                ..._customers.map((c) => ListTile(
                                  dense: true,
                                  title: Text(c.name),
                                  onTap: () => setState(() {
                                    _selectedCustomer = c;
                                    _showCustomerDropdown = false;
                                  }),
                                )),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('طريقة الدفع:'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _paymentType,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'نقدي', child: Text('💵 نقدي')),
                                  DropdownMenuItem(value: 'آجل', child: Text('📝 آجل')),
                                ],
                                onChanged: (v) => setState(() => _paymentType = v!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ============ زر الحفظ ============
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSale,
                      icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
                      label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ الفاتورة'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                    ),
                  ),
                ),

                // ============ بحث المنتجات ============
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '🔍 بحث عن منتج...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),

                // ============ شبكة المنتجات ============
                Expanded(
                  flex: 4,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return Card(
                        child: InkWell(
                          onTap: () => _addToCart(product),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory, color: AppTheme.primaryColor, size: 32),
                              const SizedBox(height: 8),
                              Text(product.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${product.retailPrice}', style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
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
