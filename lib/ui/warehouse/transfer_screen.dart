import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/stock_repository.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final StockRepository _stockRepo = StockRepository();
  List<Product> _products = [];
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _productRepo.getAll();
    if (!mounted) return;
    setState(() {
      _products = products.where((p) => p.active).toList();
      _isLoading = false;
    });
  }

  Future<void> _transfer() async {
    if (_selectedProduct == null) return;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كمية صحيحة')));
      return;
    }

    try {
      final db = await DatabaseHelper().database;
      
      // تنفيذ التحويل داخل معاملة واحدة
      await db.transaction((txn) async {
        // 1. التحقق من الكمية المتاحة في المخزون
        final stockList = await txn.query(
          'stock',
          where: 'product_id = ?',
          whereArgs: [_selectedProduct!.id],
        );
        
        if (stockList.isEmpty) {
          throw Exception('المنتج غير موجود في المخزون');
        }
        
        final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
        if (currentQty < qty) {
          throw Exception('الكمية غير متوفرة في المخزون (المتاح: $currentQty)');
        }

        // 2. خصم الكمية من المخزون
        await txn.update(
          'stock',
          {
            'quantity_pieces': currentQty - qty,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'product_id = ?',
          whereArgs: [_selectedProduct!.id],
        );

        // 3. تسجيل حركة المخزون (الخصم)
        await txn.insert('stock_movements', {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'product_id': _selectedProduct!.id,
          'movement_type': 'تحويل للمعرض',
          'quantity': -qty,
          'reference_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'reference_type': 'transfer',
          'notes': 'تحويل إلى المعرض',
          'created_at': DateTime.now().toIso8601String(),
          'created_by': 'admin',
          'device_id': 'mobile',
          'sync_status': 'Pending',
        });

        // 4. إضافة الكمية إلى المعرض
        final showroomStock = await txn.query(
          'showroom_stock',
          where: 'product_id = ?',
          whereArgs: [_selectedProduct!.id],
        );
        
        if (showroomStock.isEmpty) {
          await txn.insert('showroom_stock', {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'product_id': _selectedProduct!.id,
            'quantity': qty,
            'retail_price': _selectedProduct!.retailPrice,
            'transfer_date': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          final currentShowroom = showroomStock.first['quantity'] as int? ?? 0;
          await txn.update(
            'showroom_stock',
            {
              'quantity': currentShowroom + qty,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'product_id = ?',
            whereArgs: [_selectedProduct!.id],
          );
        }

        // 5. سجل التدقيق
        await txn.insert('audit_logs', {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'user_id': 'admin',
          'module': 'المخزن',
          'action': 'تحويل للمعرض',
          'old_data': null,
          'new_data': 'تحويل ${_selectedProduct!.name} - كمية $qty قطعة',
          'device_id': 'mobile',
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التحويل إلى المعرض')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل للمعرض')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<Product>(
                    value: _selectedProduct,
                    decoration: const InputDecoration(labelText: 'المنتج'),
                    items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (p) => setState(() => _selectedProduct = p),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'الكمية (قطع)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _transfer, child: const Text('تحويل')),
                ],
              ),
            ),
    );
  }
}
