import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/models/dynamic_configuration.dart';
import '../../data/repositories/system_management_repository.dart';

class DynamicCreationScreen extends StatefulWidget {
  const DynamicCreationScreen({super.key});

  @override
  State<DynamicCreationScreen> createState() => _DynamicCreationScreenState();
}

class _DynamicCreationScreenState extends State<DynamicCreationScreen> {
  final SystemManagementRepository _repo = SystemManagementRepository();
  List<DynamicConfiguration> _elements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _elements = await _repo.getDynamicElements();
    setState(() => _isLoading = false);
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '0');
    String selectedType = 'صفحة جديدة';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('إنشاء عنصر جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'نوع العنصر'),
                  items: const [
                    DropdownMenuItem(value: 'صفحة جديدة', child: Text('صفحة جديدة')),
                    DropdownMenuItem(value: 'تبويب', child: Text('تبويب')),
                    DropdownMenuItem(value: 'قسم', child: Text('قسم')),
                    DropdownMenuItem(value: 'حقل', child: Text('حقل')),
                    DropdownMenuItem(value: 'عمود جدول', child: Text('عمود جدول')),
                    DropdownMenuItem(value: 'نوع جديد', child: Text('نوع جديد')),
                    DropdownMenuItem(value: 'كشف جديد', child: Text('كشف جديد')),
                    DropdownMenuItem(value: 'بطاقة إحصائية', child: Text('بطاقة إحصائية')),
                    DropdownMenuItem(value: 'زر', child: Text('زر أو إجراء')),
                  ],
                  onChanged: (v) => setStateDialog(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العنصر *')),
                const SizedBox(height: 12),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'مكان الظهور')),
                const SizedBox(height: 12),
                TextField(controller: orderCtrl, decoration: const InputDecoration(labelText: 'الترتيب'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await _repo.createDynamicElement(
                  elementType: selectedType,
                  elementName: nameCtrl.text.trim(),
                  pageLocation: locationCtrl.text.trim(),
                  displayOrder: int.tryParse(orderCtrl.text) ?? 0,
                );
                Navigator.pop(ctx, true);
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _elements.isEmpty
                      ? const Center(child: Text('لا توجد عناصر ديناميكية'))
                      : ListView.builder(
                          itemCount: _elements.length,
                          itemBuilder: (context, index) {
                            final element = _elements[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  element.active ? Icons.visibility : Icons.visibility_off,
                                  color: element.active ? AppTheme.successColor : AppTheme.textSecondaryColor,
                                ),
                                title: Text(element.elementName),
                                subtitle: Text('${element.elementType} | ترتيب: ${element.displayOrder}'),
                                trailing: Switch(
                                  value: element.active,
                                  onChanged: (v) async {
                                    await _repo.toggleElement(element.id, v);
                                    _loadData();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
