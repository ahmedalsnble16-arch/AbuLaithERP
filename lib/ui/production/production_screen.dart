import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/models/production_batch.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/production_repository.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _productRepo = ProductRepository();
  final ProductionRepository _productionRepo = ProductionRepository();

  List<Product> _products = [];
  Product? _selectedProduct;

  final _hitsController = TextEditingController();
  final _piecesPerHitController = TextEditingController();
  final _goodPiecesController = TextEditingController();
  final _damagedPiecesController = TextEditingController(text: '0');
  final _lostPiecesController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  int _expectedPieces = 0;
  int _actualPieces = 0;
  int _difference = 0;
  double _lossPercent = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _productRepo.getAll();
    setState(() {
      _products = products.where((p) => p.active).toList();
    });
  }

  void _calculate() {
    final hits = int.tryParse(_hitsController.text) ?? 0;
    final piecesPerHit = int.tryParse(_piecesPerHitController.text) ?? 0;
    final damaged = int.tryParse(_damagedPiecesController.text) ?? 0;
    final lost = int.tryParse(_lostPiecesController.text) ?? 0;

    _expectedPieces = hits * piecesPerHit;
    final good = _expectedPieces - damaged - lost;
    _goodPiecesController.text = good > 0 ? good.toString() : '0';
    _actualPieces = good > 0 ? good : 0;
    _difference = _expectedPieces - _actualPieces;
    _lossPercent = _expectedPieces > 0 ? ((damaged + lost) / _expectedPieces) * 100 : 0;

    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار منتج'), backgroundColor: AppTheme.warningColor),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DatabaseHelper.now;
      final batch = ProductionBatch(
        id: const Uuid().v4(),
        productionNumber: '',
        productId: _selectedProduct!.id,
        shift: 'صباحي',
        productionDate: DateTime.now().toIso8601String().substring(0, 10),
        hits: int.tryParse(_hitsController.text) ?? 0,
        piecesPerHit: int.tryParse(_piecesPerHitController.text) ?? 0,
        expectedPieces: _expectedPieces,
        goodPieces: _actualPieces,
        damagedPieces: int.tryParse(_damagedPiecesController.text) ?? 0,
        lostPieces: int.tryParse(_lostPiecesController.text) ?? 0,
        goodBoxes: (_selectedProduct!.piecesPerBox > 0) ? _actualPieces ~/ _selectedProduct!.piecesPerBox : 0,
        damagedBoxes: 0,
        productionCost: 0,
        status: 'معتمدة',
        notes: _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _productionRepo.createBatch(batch);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الإنتاج بنجاح'), backgroundColor: AppTheme.successColor),
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
      appBar: AppBar(title: const Text('تسجيل إنتاج جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<Product>(
                value: _selectedProduct,
                decoration: const InputDecoration(labelText: 'المنتج *'),
                items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (p) => setState(() => _selectedProduct = p),
                validator: (p) => p == null ? 'اختر منتجاً' : null,
              ),
              const SizedBox(height: 12),
              TextField(controller: _hitsController, decoration: const InputDecoration(labelText: 'عدد الضربات'), keyboardType: TextInputType.number, onChanged: (_) => _calculate()),
              const SizedBox(height: 12),
              TextField(controller: _piecesPerHitController, decoration: const InputDecoration(labelText: 'عدد القطع في الضربة'), keyboardType: TextInputType.number, onChanged: (_) => _calculate()),
              const SizedBox(height: 12),
              TextField(controller: _damagedPiecesController, decoration: const InputDecoration(labelText: 'التالف'), keyboardType: TextInputType.number, onChanged: (_) => _calculate()),
              const SizedBox(height: 12),
              TextField(controller: _lostPiecesController, decoration: const InputDecoration(labelText: 'الفاقد'), keyboardType: TextInputType.number, onChanged: (_) => _calculate()),
              const SizedBox(height: 12),
              TextField(controller: _goodPiecesController, decoration: const InputDecoration(labelText: 'الإنتاج الصالح (يحسب تلقائياً)'), keyboardType: TextInputType.number, enabled: false),
              const SizedBox(height: 12),
              TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 2),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text('المتوقع: $_expectedPieces قطعة'),
                      Text('الفعلي الصالح: $_actualPieces قطعة'),
                      Text('الفرق: $_difference قطعة', style: TextStyle(color: _difference > 0 ? AppTheme.errorColor : AppTheme.successColor)),
                      Text('نسبة الهدر: ${_lossPercent.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ الإنتاج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
