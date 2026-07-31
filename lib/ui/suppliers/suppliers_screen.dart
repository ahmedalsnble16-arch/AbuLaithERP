import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen>
    with SingleTickerProviderStateMixin {
  final SettingsRepository _settingsRepo = SettingsRepository();
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // متحكمات الإعدادات
  bool _suppliersEnabled = true;
  bool _purchasesEnabled = true;
  bool _allowCredit = true;
  final TextEditingController _defaultCreditLimitCtrl = TextEditingController();
  bool _isSavingSettings = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadSuppliers();
    await _loadSettings();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSuppliers() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(DBConstants.tableSuppliers, where: 'deleted = 0', orderBy: 'name ASC');
    setState(() => _suppliers = maps);
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getAll();
    _suppliersEnabled = settings['suppliers_enabled'] != 'false';
    _purchasesEnabled = settings['purchases_enabled'] != 'false';
    _allowCredit = settings['allow_credit'] != 'false';
    _defaultCreditLimitCtrl.text = settings['default_credit_limit'] ?? '0';
    setState(() {});
  }

  Future<void> _saveSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      await _settingsRepo.setAll({
        'suppliers_enabled': _suppliersEnabled.toString(),
        'purchases_enabled': _purchasesEnabled.toString(),
        'allow_credit': _allowCredit.toString(),
        'default_credit_limit': _defaultCreditLimitCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات الموردين'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _isSavingSettings = false);
    }
  }

  Future<void> _addSupplier() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم *')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = await DatabaseHelper().database;
              final now = DatabaseHelper.now;
              await db.insert(DBConstants.tableSuppliers, {
                'id': const Uuid().v4(),
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
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
    if (result == true) _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _defaultCreditLimitCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردون'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'الموردين'),
            Tab(text: 'الإعدادات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تبويب الموردين
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(hintText: 'بحث عن مورد...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) {
                    setState(() {
                      _suppliers = _suppliers.where((s) => (s['name'] ?? '').toString().toLowerCase().contains(v.toLowerCase())).toList();
                      if (v.isEmpty) _loadSuppliers();
                    });
                  },
                ),
              ),
              Expanded(
                child: _isLoading
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
                                  trailing: Text('${s['current_balance'] ?? 0} ر.ي'),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          // تبويب الإعدادات
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إعدادات الموردين والمشتريات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('تفعيل الموردين'),
                          subtitle: const Text('تعطيل النظام يخفي جميع خيارات الموردين'),
                          value: _suppliersEnabled,
                          onChanged: (v) => setState(() => _suppliersEnabled = v),
                        ),
                        SwitchListTile(
                          title: const Text('تفعيل المشتريات'),
                          subtitle: const Text('السماح بإنشاء فواتير شراء جديدة'),
                          value: _purchasesEnabled,
                          onChanged: (v) => setState(() => _purchasesEnabled = v),
                        ),
                        SwitchListTile(
                          title: const Text('السماح بالدفع الآجل'),
                          subtitle: const Text('يمكن تسجيل فواتير شراء آجلة'),
                          value: _allowCredit,
                          onChanged: (v) => setState(() => _allowCredit = v),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _defaultCreditLimitCtrl,
                          decoration: const InputDecoration(labelText: 'الحد الائتماني الافتراضي'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSavingSettings ? null : _saveSettings,
                            child: _isSavingSettings ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ إعدادات الموردين'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addSupplier, child: const Icon(Icons.add)),
    );
  }
}
