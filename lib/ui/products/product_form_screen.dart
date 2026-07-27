import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _codeController = TextEditingController();
  final _piecesPerBoxController = TextEditingController(text: '60');
  final _wholesalePriceController = TextEditingController();
  final _retailPriceController = TextEditingController();
  final _productionCostController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final ProductRepository _productRepo = ProductRepository();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p.name;
      _barcodeController.text = p.barcode ?? '';
      _codeController.text = p.code ?? '';
      _piecesPerBoxController.text = p.piecesPerBox.toString();
      _wholesalePriceController.text = p.wholesalePrice.toString();
      _retailPriceController.text = p.retailPrice.toString();
      _productionCostController.text = p.productionCost.toString();
      _minimumStockController.text = p.minimumStock.toString();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final now = DatabaseHelper.now;
      final product = Product(
        id: widget.product?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim(),
        code: _codeController.text.trim(),
        piecesPerBox: int.tryParse(_piecesPerBoxController.text) ?? 60,
        wholesalePrice: double.tryParse(_wholesalePriceController.text) ?? 0,
        retailPrice: double.tryParse(_retailPriceController.text) ?? 0,
        productionCost: double.tryParse(_productionCostController.text) ?? 0,
        minimumStock: int.tryParse(_minimumStockController.text) ?? 0,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.product == null) {
        await _productRepo.add(product);
      } else {
        await _productRepo.update(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ بنجاح'), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل منتج')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المنتج *'), validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _barcodeController, decoration: const InputDecoration(labelText: 'الباركود')),
              const SizedBox(height: 12),
              TextFormField(controller: _codeController, decoration: const InputDecoration(labelText: 'الكود الداخلي')),
              const SizedBox(height: 12),
              TextFormField(controller: _piecesPerBoxController, decoration: const InputDecoration(labelText: 'عدد القطع في السلة'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(controller: _wholesalePriceController, decoration: const InputDecoration(labelText: 'سعر الجملة'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(controller: _retailPriceController, decoration: const InputDecoration(labelText: 'سعر التجزئة'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(controller: _productionCostController, decoration: const InputDecoration(labelText: 'تكلفة الإنتاج'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(controller: _minimumStockController, decoration: const InputDecoration(labelText: 'الحد الأدنى للمخزون'), keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
