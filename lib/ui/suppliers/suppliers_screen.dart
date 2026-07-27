import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final maps = await db.query(DBConstants.tableSuppliers, where: 'deleted = 0', orderBy: 'name ASC');
    setState(() {
      _suppliers = maps;
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم *')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'الهاتف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final db = await DatabaseHelper().database;
              final now = DatabaseHelper.now;
              await db.insert(DBConstants.tableSuppliers, {
                'id': const Uuid().v4(),
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'opening_balance': 0,
                'current_balance': 0,
                'active': 1,
                'created_at': now,
                'updated_at': now,
                'sync_status': 'Pending',
                'deleted': 0,
              });
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
      appBar: AppBar(title: const Text('الموردون')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? const Center(child: Text('لا يوجد موردون'))
              : ListView.builder(
                  itemCount: _suppliers.length,
                  itemBuilder: (context, index) {
                    final s = _suppliers[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.business, color: Colors.white)),
                        title: Text(s['name'] ?? ''),
                        subtitle: Text(s['phone'] ?? ''),
                        trailing: Text('${s['current_balance'] ?? 0}'),
                      ),
                    );
                  },
                ),
    );
  }
}
