import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/db_constants.dart';
import '../../data/models/worker.dart';
import '../../data/repositories/worker_repository.dart';
import 'worker_account_screen.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  final WorkerRepository _repo = WorkerRepository();
  List<Worker> _workers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workers = await _repo.getAll();
      setState(() { _workers = workers; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditWorker({Worker? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final jobCtrl = TextEditingController(text: existing?.job ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final dailySalaryCtrl = TextEditingController(text: '${existing?.dailySalary ?? 0}');
    final dailyExpenseCtrl = TextEditingController(text: '${existing?.dailyExpense ?? 0}');
    final cardNumberCtrl = TextEditingController(text: existing?.cardNumber ?? '');
    String? cardImagePath = existing?.cardImage;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة عامل' : 'تعديل عامل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم *')),
                TextField(controller: jobCtrl, decoration: const InputDecoration(labelText: 'الوظيفة')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف')),
                TextField(controller: dailySalaryCtrl, decoration: const InputDecoration(labelText: 'الأجر اليومي'), keyboardType: TextInputType.number),
                TextField(controller: dailyExpenseCtrl, decoration: const InputDecoration(labelText: 'المصروف اليومي'), keyboardType: TextInputType.number),
                TextField(controller: cardNumberCtrl, decoration: const InputDecoration(labelText: 'رقم البطاقة')),
                const SizedBox(height: 12),
                // صورة البطاقة
                InkWell(
                  onTap: () async {
                    final picked = await _picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setDialogState(() => cardImagePath = picked.path);
                    }
                  },
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: cardImagePath != null
                        ? Image.file(File(cardImagePath!), fit: BoxFit.cover)
                        : const Icon(Icons.camera_alt, size: 40, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final worker = Worker(
                  id: existing?.id ?? '',
                  name: nameCtrl.text.trim(),
                  job: jobCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  dailySalary: double.tryParse(dailySalaryCtrl.text) ?? 0,
                  dailyExpense: double.tryParse(dailyExpenseCtrl.text) ?? 0,
                  cardNumber: cardNumberCtrl.text.trim(),
                  cardImage: cardImagePath,
                  active: existing?.active ?? true,
                  createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                );
                if (existing == null) {
                  await _repo.add(worker);
                } else {
                  await _repo.update(worker);
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _loadWorkers();
  }

  Future<void> _toggleActive(Worker worker) async {
    final updated = worker.copyWith(active: !worker.active);
    await _repo.update(updated);
    _loadWorkers();
  }

  Future<void> _deleteWorker(Worker worker) async {
    // التحقق من وجود حركات مالية
    final db = await DatabaseHelper().database;
    final transactions = await db.query(
      DBConstants.tableWorkerAccounts,
      where: 'worker_id = ?',
      whereArgs: [worker.id],
    );
    if (transactions.isNotEmpty) {
      // تعطيل بدلاً من حذف
      await _repo.update(worker.copyWith(active: false));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعطيل العامل لوجود حركات مالية سابقة')),
      );
    } else {
      await _repo.delete(worker.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف العامل')),
      );
    }
    _loadWorkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العمال')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(hintText: 'بحث عن عامل...', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => _loadWorkers(),
                  ),
                ),
                Expanded(
                  child: _workers.isEmpty
                      ? const Center(child: Text('لا يوجد عمال'))
                      : ListView.builder(
                          itemCount: _workers.length,
                          itemBuilder: (context, index) {
                            final w = _workers[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: w.active ? AppTheme.successColor : AppTheme.textSecondaryColor,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${w.job ?? ""} | الأجر: ${w.dailySalary} | المصروف: ${w.dailyExpense}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') _addOrEditWorker(existing: w);
                                    if (value == 'toggle') _toggleActive(w);
                                    if (value == 'delete') _deleteWorker(w);
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'edit', child: Text('✏️ تعديل')),
                                    PopupMenuItem(value: 'toggle', child: Text(w.active ? '⏸️ تعطيل' : '✅ تنشيط')),
                                    const PopupMenuItem(value: 'delete', child: Text('🗑️ حذف')),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WorkerAccountScreen(
                                        workerId: w.id,
                                        workerName: w.name,
                                        dailySalary: w.dailySalary,
                                        dailyExpense: w.dailyExpense,
                                        isActive: w.active,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditWorker(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
