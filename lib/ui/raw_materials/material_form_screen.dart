import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/raw_material.dart';
import '../../data/repositories/raw_material_repository.dart';

class MaterialFormScreen extends StatefulWidget {
  final RawMaterial? material;
  const MaterialFormScreen({super.key, this.material});

  @override
  State<MaterialFormScreen> createState() => _MaterialFormScreenState();
}

class _MaterialFormScreenState extends State<MaterialFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController(text: 'كيلو');
  final _purchasePriceController = TextEditingController();
  final _minimumQtyController = TextEditingController();
  final _notesController = TextEditingController();
  final RawMaterialRepository _materialRepo = RawMaterialRepository();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.material != null) {
      final m = widget.material!;
      _nameController.text = m.name;
      _unitController.text = m.unit;
      _purchasePriceController.text = m.purchasePrice.toString();
      _minimumQtyController.text = m.minimumQty.toString();
      _notesController.text = m.notes ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final now = DatabaseHelper.now;
      final material = RawMaterial(
        id: widget.material?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        unit: _unitController.text.trim(),
        purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
        minimumQty: double.tryParse(_minimumQtyController.text) ?? 0,
        notes: _notesController.text.trim(),
        createdAt: widget.material?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.material == null) {
        await _materialRepo.add(material);
      } else {
        await _materialRepo.update(material);
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
      appBar: AppBar(title: Text(widget.material == null ? 'إضافة مادة خام' : 'تعديل مادة خام')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'اسم المادة *'), validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _unitController, decoration: const InputDecoration(labelText: 'الوحدة')),
              const SizedBox(height: 12),
              TextFormField(controller: _purchasePriceController, decoration: const InputDecoration(labelText: 'سعر الشراء'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(controller: _minimumQtyController, decoration: const InputDecoration(labelText: 'الحد الأدنى للتنبيه'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 3),
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
