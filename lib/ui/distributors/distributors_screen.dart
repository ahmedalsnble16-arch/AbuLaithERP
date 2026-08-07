import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/distributor.dart';
import '../../data/repositories/distributor_repository.dart';
import 'distributor_account_screen.dart';
import 'distributor_prices_screen.dart';

class DistributorsScreen extends StatefulWidget {
  const DistributorsScreen({super.key});

  @override
  State<DistributorsScreen> createState() => _DistributorsScreenState();
}

class _DistributorsScreenState extends State<DistributorsScreen> {
  final DistributorRepository _repo = DistributorRepository();
  List<Distributor> _distributors = [];
  List<Distributor> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.getAll();
      setState(() {
        _distributors = list;
        _filtered = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      _filtered = _distributors
          .where((d) => d.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _addDistributor() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final commissionCtrl = TextEditingController(text: '5');
    final active = ValueNotifier<bool>(true);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('إضافة موزع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الموزع *')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                TextField(controller: vehicleCtrl, decoration: const InputDecoration(labelText: 'رقم السيارة')),
                TextField(controller: commissionCtrl, decoration: const InputDecoration(labelText: 'نسبة الخصم %'), keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('نشط'),
                  value: active.value,
                  onChanged: (v) => setStateDialog(() => active.value = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final d = Distributor(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  vehicle: vehicleCtrl.text.trim(),
                  commissionPercent: double.tryParse(commissionCtrl.text) ?? 5,
                  active: active.value,
                  createdAt: DatabaseHelper.now,
                  updatedAt: DatabaseHelper.now,
                );
                final newId = await _repo.addDistributor(d);
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

  Future<void> _editDistributor(Distributor d) async {
    final nameCtrl = TextEditingController(text: d.name);
    final phoneCtrl = TextEditingController(text: d.phone ?? '');
    final vehicleCtrl = TextEditingController(text: d.vehicle ?? '');
    final commissionCtrl = TextEditingController(text: d.commissionPercent.toString());
    final active = ValueNotifier<bool>(d.active);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('تعديل موزع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الموزع *')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                TextField(controller: vehicleCtrl, decoration: const InputDecoration(labelText: 'رقم السيارة')),
                TextField(controller: commissionCtrl, decoration: const InputDecoration(labelText: 'نسبة الخصم %'), keyboardType: TextInputType.number),
                SwitchListTile(
                  title: const Text('نشط'),
                  value: active.value,
                  onChanged: (v) => setStateDialog(() => active.value = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final updated = Distributor(
                  id: d.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  vehicle: vehicleCtrl.text.trim(),
                  commissionPercent: double.tryParse(commissionCtrl.text) ?? 5,
                  active: active.value,
                  createdAt: d.createdAt,
                  updatedAt: DatabaseHelper.now,
                );
                await _repo.updateDistributor(updated);
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

  Future<void> _deleteDistributor(Distributor d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الموزع "${d.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor)),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.deleteDistributor(d.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الموزعون')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: 'بحث عن موزع...', prefixIcon: Icon(Icons.search)),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('لا يوجد موزعون'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final d = _filtered[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: d.active ? Colors.indigo : Colors.grey,
                                child: Icon(Icons.local_shipping, color: Colors.white),
                              ),
                              title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (d.vehicle != null && d.vehicle!.isNotEmpty)
                                    Text('السيارة: ${d.vehicle}'),
                                  if (d.phone != null && d.phone!.isNotEmpty)
                                    Text('الهاتف: ${d.phone}'),
                                  Text('الخصم: ${d.commissionPercent}% | الحالة: ${d.active ? "نشط" : "غير نشط"}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'account':
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => DistributorAccountScreen(distributor: d))).then((_) => _load());
                                      break;
                                    case 'prices':
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => DistributorPricesScreen(distributorId: d.id, distributorName: d.name)));
                                      break;
                                    case 'edit':
                                      _editDistributor(d);
                                      break;
                                    case 'delete':
                                      _deleteDistributor(d);
                                      break;
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'account', child: Text('📄 كشف حساب')),
                                  const PopupMenuItem(value: 'prices', child: Text('💰 أسعار المنتجات')),
                                  const PopupMenuItem(value: 'edit', child: Text('✏️ تعديل')),
                                  const PopupMenuItem(value: 'delete', child: Text('🗑️ حذف')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addDistributor, child: const Icon(Icons.add)),
    );
  }
}
