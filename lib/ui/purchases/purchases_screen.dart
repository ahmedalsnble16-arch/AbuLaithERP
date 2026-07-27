import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    _suppliers = await db.query(DBConstants.tableSuppliers, where: 'deleted = 0');
    _materials = await db.query(DBConstants.tableRawMaterials, where: 'deleted = 0');
    _purchases = await db.query(DBConstants.tablePurchases, where: 'deleted = 0', orderBy: 'purchase_date DESC');
    setState(() => _isLoading = false);
  }

  Future<void> _add() async {
    String? selectedSupplier;
    String? selectedMaterial;
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    String paymentType = 'نقدي';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('فاتورة شراء'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'المورد *'),
                  items: _suppliers.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s['id'] as String, child: Text(s['name'] ?? ''))).toList(),
                  onChanged: (v) => setDialogState(() => selectedSupplier = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'المادة *'),
                  items: _materials.map<DropdownMenuItem<String>>((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['name'] ?? ''))).toList(),
                  onChanged: (v) => setDialogState(() => selectedMaterial = v),
                ),
                const SizedBox(height: 8),
                TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'السعر'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: paymentType,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                    DropdownMenuItem(value: 'آجل', child: Text('آجل')),
                  ],
                  onChanged: (v) => setDialogState(() => paymentType = v ?? 'نقدي'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (selectedSupplier == null || selectedMaterial == null) return;
                final db = await DatabaseHelper().database;
                final now = DatabaseHelper.now;
                final qty = double.tryParse(quantityController.text) ?? 0;
                final price = double.tryParse(priceController.text) ?? 0;
                final total = qty * price;
                final purchaseId = const Uuid().v4();

                await db.insert(DBConstants.tablePurchases, {
                  'id': purchaseId,
                  'supplier_id': selectedSupplier,
                  'invoice_number': 'PUR-${DateTime.now().millisecondsSinceEpoch}',
                  'total': total,
                  'paid': paymentType == 'نقدي' ? total : 0,
                  'remaining': paymentType == 'آجل' ? total : 0,
                  'payment_type': paymentType,
                  'payment_status': paymentType == 'نقدي' ? 'مدفوعة' : 'غير مدفوعة',
                  'purchase_date': DateTime.now().toIso8601String().substring(0, 10),
                  'status': 'معتمدة',
                  'created_at': now,
                  'updated_at': now,
                  'sync_status': 'Pending',
                  'deleted': 0,
                });

                await db.insert(DBConstants.tablePurchaseItems, {
                  'id': const Uuid().v4(),
                  'purchase_id': purchaseId,
                  'material_id': selectedMaterial,
                  'quantity': qty,
                  'unit_price': price,
                  'total': total,
                  'created_at': now,
                });

                final rawStock = await db.query(DBConstants.tableRawStock, where: 'material_id = ?', whereArgs: [selectedMaterial]);
                if (rawStock.isEmpty) {
                  await db.insert(DBConstants.tableRawStock, {
                    'id': const Uuid().v4(),
                    'material_id': selectedMaterial,
                    'quantity': qty,
                    'created_at': now,
                    'updated_at': now,
                  });
                } else {
                  final currentQty = (rawStock.first['quantity'] as num?)?.toDouble() ?? 0;
                  await db.update(DBConstants.tableRawStock, {
                    'quantity': currentQty + qty,
                    'updated_at': now,
                  }, where: 'material_id = ?', whereArgs: [selectedMaterial]);
                }

                if (paymentType == 'نقدي') {
                  await db.insert(DBConstants.tableTreasury, {
                    'id': const Uuid().v4(),
                    'transaction_number': 'TXN-${DateTime.now().millisecondsSinceEpoch}',
                    'transaction_type': 'صرف',
                    'amount': total,
                    'source_module': 'مشتريات',
                    'source_id': purchaseId,
                    'note': 'شراء مواد خام',
                    'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
                    'status': 'معتمدة',
                    'created_at': now,
                    'updated_at': now,
                    'sync_status': 'Pending',
                  });
                }

                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المشتريات')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
              ? const Center(child: Text('لا توجد فواتير شراء'))
              : ListView.builder(
                  itemCount: _purchases.length,
                  itemBuilder: (context, index) {
                    final p = _purchases[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.shopping_cart, color: Colors.white)),
                        title: Text(p['invoice_number'] ?? ''),
                        subtitle: Text('${p['purchase_date']} | ${p['payment_type']}'),
                        trailing: Text('${p['total']}'),
                      ),
                    );
                  },
                ),
    );
  }
}
