import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/dynamic_configuration.dart';
import '../../data/repositories/system_management_repository.dart';

class DynamicCreationScreen extends StatefulWidget {
  const DynamicCreationScreen({super.key});

  @override
  State<DynamicCreationScreen> createState() => _DynamicCreationScreenState();
}

class _DynamicCreationScreenState extends State<DynamicCreationScreen> {
  final SystemManagementRepository _repo = SystemManagementRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  List<DynamicConfiguration> _elements = [];
  List<String> _repairTypes = [];
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _elements = await _repo.getDynamicElements();
      _repairTypes = await _getTableValues(DBConstants.tableRepairTypes, 'name');
      _categories = await _getTableValues(DBConstants.tableCategories, 'name');
    } catch (e) {
      _showError('خطأ في تحميل البيانات: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<List<String>> _getTableValues(String tableName, String columnName) async {
    final db = await _dbHelper.database;
    final maps = await db.query(tableName);
    final values = <String>{};
    for (var map in maps) {
      final value = map[columnName];
      if (value != null && value.toString().isNotEmpty) {
        values.add(value.toString());
      }
    }
    return values.toList();
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '0');
    final settingsCtrl = TextEditingController();
    String selectedType = 'نوع جديد';
    String selectedTarget = 'repair_types';
    bool affectsTreasury = false;

    // ========== المرحلة 1: إدخال البيانات ==========
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('إنشاء عنصر جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'نوع العنصر',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'نوع جديد', child: Text('نوع جديد (إصلاح/تصنيف)')),
                    DropdownMenuItem(value: 'صفحة جديدة', child: Text('صفحة جديدة')),
                    DropdownMenuItem(value: 'تبويب', child: Text('تبويب')),
                    DropdownMenuItem(value: 'قسم', child: Text('قسم')),
                    DropdownMenuItem(value: 'حقل', child: Text('حقل')),
                    DropdownMenuItem(value: 'عمود جدول', child: Text('عمود جدول')),
                    DropdownMenuItem(value: 'كشف جديد', child: Text('كشف جديد')),
                    DropdownMenuItem(value: 'بطاقة إحصائية', child: Text('بطاقة إحصائية')),
                    DropdownMenuItem(value: 'زر/إجراء', child: Text('زر أو إجراء')),
                  ],
                  onChanged: (v) => setStateDialog(() => selectedType = v!),
                ),
                const SizedBox(height: 16),

                if (selectedType == 'نوع جديد') ...[
                  DropdownButtonFormField<String>(
                    value: selectedTarget,
                    decoration: const InputDecoration(
                      labelText: 'الجدول الهدف',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'repair_types', child: Text('أنواع الإصلاحات')),
                      DropdownMenuItem(value: 'categories', child: Text('التصنيفات')),
                    ],
                    onChanged: (v) => setStateDialog(() => selectedTarget = v!),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم العنصر *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'مكان الظهور',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: orderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الترتيب',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sort),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('يؤثر على الخزنة؟'),
                  value: affectsTreasury,
                  onChanged: (v) => setStateDialog(() => affectsTreasury = v),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: settingsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'إعدادات إضافية (JSON)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.settings),
                    hintText: '{"enabled": true}',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  _showError('يرجى إدخال اسم العنصر');
                  return;
                }
                Navigator.pop(ctx, {
                  'type': selectedType,
                  'target': selectedTarget,
                  'name': nameCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'order': int.tryParse(orderCtrl.text) ?? 0,
                  'affectsTreasury': affectsTreasury,
                  'settings': settingsCtrl.text.trim(),
                });
              },
              child: const Text('التالي: معاينة'),
            ),
          ],
        ),
      ),
    );

    if (data == null) return;

    // ========== المرحلة 2: المعاينة قبل الإنشاء ==========
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.preview, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('معاينة العنصر'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _previewRow('النوع', data['type']?.toString() ?? ''),
              if (data['type'] == 'نوع جديد') ...[
                _previewRow('الجدول الهدف', data['target']?.toString() ?? ''),
              ],
              _previewRow('الاسم', data['name']?.toString() ?? ''),
              if (data['location']?.toString().isNotEmpty ?? false) ...[
                _previewRow('المكان', data['location']?.toString() ?? ''),
              ],
              _previewRow('الترتيب', '${data['order']}'),
              _previewRow('يؤثر على الخزنة', data['affectsTreasury'] == true ? 'نعم' : 'لا'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✓ سيتم إنشاء العنصر وحفظه في قاعدة البيانات', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 4),
                    Text('✓ سيظهر في المكان المحدد', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 4),
                    Text('✓ يمكن تعديله أو إخفاؤه لاحقاً', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('تأكيد الإنشاء'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ========== المرحلة 3: التنفيذ ==========
    try {
      if (data['type'] == 'نوع جديد') {
        await _repo.createNewType(
          tableName: data['target']?.toString() ?? 'repair_types',
          typeName: data['name']?.toString() ?? '',
        );
      } else {
        await _repo.createDynamicElement(
          elementType: data['type']?.toString() ?? '',
          elementName: data['name']?.toString() ?? '',
          pageLocation: data['location']?.toString().isEmpty ?? true
              ? null
              : data['location']?.toString(),
          displayOrder: data['order'] as int? ?? 0,
          settings: data['settings']?.toString().isEmpty ?? true
              ? null
              : data['settings']?.toString(),
          affectsTreasury: data['affectsTreasury'] as bool? ?? false,
        );
      }
      _showSuccess('تم الإنشاء بنجاح');
      _loadData();
    } catch (e) {
      _showError('فشل الإنشاء: $e');
    }
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ملخص الأنواع الموجودة
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Text('أنواع الإصلاحات', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('${_repairTypes.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Text('التصنيفات', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('${_categories.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Text('العناصر الديناميكية', style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('${_elements.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // قائمة العناصر الديناميكية
                Expanded(
                  child: _elements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_circle_outline, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد عناصر ديناميكية\nاضغط + لإنشاء عنصر جديد',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _elements.length,
                          itemBuilder: (context, index) {
                            final element = _elements[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  element.active ? Icons.visibility : Icons.visibility_off,
                                  color: element.active ? AppTheme.successColor : AppTheme.textSecondaryColor,
                                ),
                                title: Text(
                                  element.elementName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${element.elementType}${element.pageLocation != null && element.pageLocation!.isNotEmpty ? ' | ${element.pageLocation}' : ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: element.active,
                                      onChanged: (v) async {
                                        await _repo.toggleElement(element.id, v);
                                        _loadData();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('حذف العنصر'),
                                            content: Text('هل تريد حذف "${element.elementName}"؟\nسيتم أرشفته وليس حذفه نهائياً.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('إلغاء'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('حذف'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await _repo.deleteElement(element.id);
                                          _loadData();
                                        }
                                      },
                                    ),
                                  ],
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
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
        tooltip: 'إنشاء عنصر جديد',
      ),
    );
  }
}
