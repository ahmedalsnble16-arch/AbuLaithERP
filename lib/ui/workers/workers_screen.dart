import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import 'worker_account_screen.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    _workers = await db.query(DBConstants.tableWorkers, where: 'deleted = 0', orderBy: 'name ASC');
    setState(() => _isLoading = false);
  }

  Future<void> _add() async {
    final nameController = TextEditingController();
    final jobController = TextEditingController();
    final phoneController = TextEditingController();
    final salaryController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة عامل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم *')),
            TextField(controller: jobController, decoration: const InputDecoration(labelText: 'الوظيفة')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'الهاتف')),
            TextField(controller: salaryController, decoration: const InputDecoration(labelText: 'الراتب'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final db = await DatabaseHelper().database;
              final now = DatabaseHelper.now;
              await db.insert(DBConstants.tableWorkers, {
                'id': const Uuid().v4(),
                'name': nameController.text.trim(),
                'job': jobController.text.trim(),
                'phone': phoneController.text.trim(),
                'salary': double.tryParse(salaryController.text) ?? 0,
                'hire_date': DateTime.now().toIso8601String().substring(0, 10),
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
      appBar: AppBar(title: const Text('العمال')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workers.isEmpty
              ? const Center(child: Text('لا يوجد عمال'))
              : ListView.builder(
                  itemCount: _workers.length,
                  itemBuilder: (context, index) {
                    final w = _workers[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(w['name'] ?? ''),
                        subtitle: Text('${w['job'] ?? ""} | الراتب: ${w['salary'] ?? 0}'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerAccountScreen(workerId: w['id'], workerName: w['name'] ?? ''))),
                      ),
                    );
                  },
                ),
    );
  }
}
