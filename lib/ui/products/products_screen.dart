import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  final ProductRepository _productRepo = ProductRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // متحكمات الإعدادات
  final TextEditingController _defaultWholesaleCtrl = TextEditingController();
  final TextEditingController _defaultRetailCtrl = TextEditingController();
  final TextEditingController _defaultMinStockCtrl = TextEditingController();
  bool _barcodeEnabled = false;
  bool _allowPriceEdit = true;
  bool _isSavingSettings = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepo.getAll();
      setState(() {
        _products = products;
        _filteredProducts = products;
      });
    } catch (e) {
      // ignore
    }
    await _loadProductSettings();
    setState(() => _isLoading = false);
  }

  Future<void> _loadProductSettings() async {
    final settings = await _settingsRepo.getAll();
    _defaultWholesaleCtrl.text = settings['default_wholesale_price'] ?? '0';
    _defaultRetailCtrl.text = settings['default_retail_price'] ?? '0';
    _defaultMinStockCtrl.text = settings['default_min_stock'] ?? '0';
    _barcodeEnabled = settings['barcode_enabled'] == 'true';
    _allowPriceEdit = settings['allow_price_edit'] != 'false';
    setState(() {});
  }

  Future<void> _saveProductSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      await _settingsRepo.setAll({
        'default_wholesale_price': _defaultWholesaleCtrl.text.trim(),
        'default_retail_price': _defaultRetailCtrl.text.trim(),
        'default_min_stock': _defaultMinStockCtrl.text.trim(),
        'barcode_enabled': _barcodeEnabled.toString(),
        'allow_price_edit': _allowPriceEdit.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ إعدادات المنتجات'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _isSavingSettings = false);
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _products
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _defaultWholesaleCtrl.dispose();
    _defaultRetailCtrl.dispose();
    _defaultMinStockCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'المنتجات'),
            Tab(text: 'الإعدادات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تبويب المنتجات
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'بحث عن منتج...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: Icon(Icons.clear),
                  ),
                  onChanged: _filterProducts,
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                        ? const Center(child: Text('لا توجد منتجات'))
                        : ListView.builder(
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor,
                                    child: Text(
                                      product.name.isNotEmpty
                                          ? product.name[0]
                                          : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(product.name),
                                  subtitle: Text(
                                      'السلة: ${product.piecesPerBox} قطعة | السعر: ${product.retailPrice}'),
                                  trailing: PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                          value: 'edit', child: Text('تعديل')),
                                      const PopupMenuItem(
                                          value: 'delete', child: Text('حذف')),
                                    ],
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProductFormScreen(
                                                product: product),
                                          ),
                                        ).then((_) => _loadData());
                                      } else if (value == 'delete') {
                                        await _productRepo.delete(product.id);
                                        _loadData();
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          // تبويب الإعدادات
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إعدادات المنتجات',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor)),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('تفعيل الباركود'),
                          subtitle: const Text('إظهار حقل الباركود عند إضافة منتج'),
                          value: _barcodeEnabled,
                          onChanged: (v) => setState(() => _barcodeEnabled = v),
                        ),
                        SwitchListTile(
                          title: const Text('السماح بتعديل سعر البيع'),
                          subtitle:
                              const Text('يمكن تعديل السعر مباشرة من شاشة البيع'),
                          value: _allowPriceEdit,
                          onChanged: (v) => setState(() => _allowPriceEdit = v),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _defaultWholesaleCtrl,
                          decoration: const InputDecoration(
                              labelText: 'سعر الجملة الافتراضي'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _defaultRetailCtrl,
                          decoration: const InputDecoration(
                              labelText: 'سعر التجزئة الافتراضي'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _defaultMinStockCtrl,
                          decoration: const InputDecoration(
                              labelText: 'الحد الأدنى الافتراضي للمخزون'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSavingSettings ? null : _saveProductSettings,
                            child: _isSavingSettings
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('حفظ إعدادات المنتجات'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        ).then((_) => _loadData()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
