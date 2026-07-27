import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final maps = await db.query(DBConstants.tableCustomers, where: 'deleted = 0', orderBy: 'name ASC');
    setState(() {
      _customers = maps.map((m) => Customer.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة عميل'),
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
              await db.insert(DBConstants.tableCustomers, {
                'id': const Uuid().v4(),
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'credit_limit': 0,
                'balance': 0,
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
      appBar: AppBar(title: const Text('العملاء')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(child: Text('لا يوجد عملاء'))
              : ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(c.name),
                        subtitle: Text(c.phone ?? ''),
                        trailing: Text('${c.balance}'),
                      ),
                    );
                  },
                ),
    );
  }
}
