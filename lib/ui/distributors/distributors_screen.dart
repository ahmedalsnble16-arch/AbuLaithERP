import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/distributor.dart';
import '../../data/repositories/distributor_repository.dart';
import 'distributor_load_screen.dart';
import 'distributor_settle_screen.dart';

class DistributorsScreen extends StatefulWidget {
  const DistributorsScreen({super.key});

  @override
  State<DistributorsScreen> createState() => _DistributorsScreenState();
}

class _DistributorsScreenState extends State<DistributorsScreen> {
  final DistributorRepository _repo = DistributorRepository();
  List<Distributor> _distributors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _distributors = await _repo.getAll();
    setState(() => _isLoading = false);
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final vehicleController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة موزع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'الهاتف')),
            TextField(controller: vehicleController, decoration: const InputDecoration(labelText: 'السيارة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final d = Distributor(
                id: const Uuid().v4(),
                name: nameController.text,
                phone: phoneController.text,
                vehicle: vehicleController.text,
                createdAt: DatabaseHelper.now,
                updatedAt: DatabaseHelper.now,
              );
              await _repo.addDistributor(d);
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الموزعون')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _distributors.isEmpty
              ? const Center(child: Text('لا يوجد موزعون'))
              : ListView.builder(
                  itemCount: _distributors.length,
                  itemBuilder: (context, index) {
                    final d = _distributors[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.local_shipping, color: Colors.white)),
                        title: Text(d.name),
                        subtitle: Text(d.vehicle ?? ''),
                        trailing: PopupMenuButton(
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'load', child: Text('تحميل')),
                            const PopupMenuItem(value: 'settle', child: Text('تصفية')),
                          ],
                          onSelected: (val) {
                            if (val == 'load') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => DistributorLoadScreen(distributorId: d.id, distributorName: d.name)));
                            } else if (val == 'settle') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => DistributorSettleScreen(distributorId: d.id, distributorName: d.name)));
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
