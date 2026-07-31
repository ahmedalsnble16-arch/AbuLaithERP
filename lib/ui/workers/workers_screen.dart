import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';
import 'worker_account_screen.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen>
    with SingleTickerProviderStateMixin {
  final SettingsRepository _settingsRepo = SettingsRepository();
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // متحكمات الإعدادات
  bool _workersEnabled = true;
  bool _autoCalculateSalary = true;
  bool _allowAdvances = true;
  bool _allowBraneyat = true;
  final TextEditingController _defaultSalaryCtrl = TextEditingController();
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
    await _loadWorkers();
    await _loadSettings();
    setState(() => _isLoading = false);
  }

  Future<void> _loadWorkers() async {
    final db = await DatabaseHelper().database;
    final workers = await db.query(DBConstants.tableWorkers, where: 'deleted = 0', orderBy: 'name ASC');
    setState(() => _workers = workers);
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getAll();
    _workersEnabled = settings['workers_enabled'] != 'false';
    _autoCalculateSalary = settings['auto_calculate_salary'] != 'false';
    _allowAdvances = settings['allow_advances'] != 'false';
    _allowBraneyat = settings['allow_braneyat'] != 'false';
    _defaultSalaryCtrl.text = settings['default_daily_salary'] ?? '0';
    setState(() {});
  }

  Future<void> _saveSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      await _settingsRepo.setAll({
        'workers_enabled': _workersEnabled.toString(),
        'auto_calculate_salary': _autoCalculateSalary.toString(),
        'allow_advances': _allowAdvances.toString(),
        'allow_braneyat': _allowBraneyat.toString(),
        'default_daily_salary': _defaultSalaryCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات العمال'), backgroundColor: AppTheme.successColor),
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

  Future<void> _addWorker() async {
    final nameCtrl = TextEditingController();
    final jobCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salaryCtrl = TextEditingController(text: _defaultSalaryCtrl.text);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة عامل'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم *')),
              TextField(controller: jobCtrl, decoration: const InputDecoration(labelText: 'الوظيفة')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف')),
              TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: 'الأجر اليومي'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = await DatabaseHelper().database;
              final now = DatabaseHelper.now;
              await db.insert(DBConstants.tableWorkers, {
                'id': const Uuid().v4(),
                'name': nameCtrl.text.trim(),
                'job': jobCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'salary': double.tryParse(salaryCtrl.text) ?? 0,
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
    if (result == true) _loadWorkers();
  }

  Future<void> _toggleWorkerStatus(String workerId, bool isActive) async {
    final db = await DatabaseHelper().database;
    await db.update(
      DBConstants.tableWorkers,
      {'active': isActive ? 1 : 0, 'updated_at': DatabaseHelper.now},
      where: 'id = ?',
      whereArgs: [workerId],
    );
    _loadWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _defaultSalaryCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العمال'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'العمال'),
            Tab(text: 'الإعدادات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تبويب العمال
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(hintText: 'بحث عن عامل...', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) {
                    setState(() {
                      _workers = _workers.where((w) => (w['name'] ?? '').toString().toLowerCase().contains(v.toLowerCase())).toList();
                      if (v.isEmpty) _loadWorkers();
                    });
                  },
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _workers.isEmpty
                        ? const Center(child: Text('لا يوجد عمال'))
                        : ListView.builder(
                            itemCount: _workers.length,
                            itemBuilder: (context, index) {
                              final w = _workers[index];
                              final isActive = w['active'] == 1;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isActive ? AppTheme.successColor : AppTheme.textSecondaryColor,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(w['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${w['job'] ?? ""} | الأجر: ${w['salary'] ?? 0} ر.ي/يوم'),
                                  trailing: Switch(
                                    value: isActive,
                                    onChanged: (v) => _toggleWorkerStatus(w['id'] as String, v),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => WorkerAccountScreen(
                                          workerId: w['id'] as String,
                                          workerName: w['name'] ?? '',
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
                        const Text('إعدادات العمال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('تفعيل نظام العمال'),
                          subtitle: const Text('تعطيل النظام يخفي جميع خيارات العمال'),
                          value: _workersEnabled,
                          onChanged: (v) => setState(() => _workersEnabled = v),
                        ),
                        SwitchListTile(
                          title: const Text('احتساب الأجر تلقائياً'),
                          subtitle: const Text('يحسب الأجر اليومي تلقائياً للعامل النشط'),
                          value: _autoCalculateSalary,
                          onChanged: (v) => setState(() => _autoCalculateSalary = v),
                        ),
                        SwitchListTile(
                          title: const Text('السماح بالسلف'),
                          subtitle: const Text('يمكن للعمال طلب سلف'),
                          value: _allowAdvances,
                          onChanged: (v) => setState(() => _allowAdvances = v),
                        ),
                        SwitchListTile(
                          title: const Text('السماح بالبرانيات'),
                          subtitle: const Text('يمكن تسجيل برانيات للعمال'),
                          value: _allowBraneyat,
                          onChanged: (v) => setState(() => _allowBraneyat = v),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _defaultSalaryCtrl,
                          decoration: const InputDecoration(labelText: 'الأجر اليومي الافتراضي'),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSavingSettings ? null : _saveSettings,
                            child: _isSavingSettings ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ إعدادات العمال'),
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
      floatingActionButton: FloatingActionButton(onPressed: _addWorker, child: const Icon(Icons.add)),
    );
  }
}
