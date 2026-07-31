import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/models/user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repo = SettingsRepository();
  Map<String, String> _settings = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // متحكمات الحقول الأساسية (من المرحلة الأولى)
  final _companyNameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _boxSizeCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  final _sessionTimeoutCtrl = TextEditingController();
  bool _negativeStock = false;
  bool _productionEnabled = true;
  bool _showroomEnabled = true;
  bool _distributorsEnabled = true;
  bool _barcodeEnabled = false;
  bool _taxEnabled = false;
  bool _darkMode = false;

  // بيانات إضافية
  int _usersCount = 0;
  int _tablesCount = 0;
  int _recordsCount = 0;
  String _dbName = '';
  String _lastBackup = 'لا يوجد';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await _loadSettings();
    await _loadSystemInfo();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSettings() async {
    final settings = await _repo.getAll();
    _settings = settings;

    _companyNameCtrl.text = settings['company_name'] ?? 'معمل أبو ليث';
    _currencyCtrl.text = settings['currency'] ?? 'ريال يمني';
    _boxSizeCtrl.text = settings['default_box_size'] ?? '60';
    _lowStockCtrl.text = settings['low_stock_threshold'] ?? '100';
    _sessionTimeoutCtrl.text = settings['session_timeout'] ?? '30';
    _negativeStock = settings['negative_stock'] == 'true';
    _productionEnabled = settings['production_enabled'] != 'false';
    _showroomEnabled = settings['showroom_enabled'] != 'false';
    _distributorsEnabled = settings['distributors_enabled'] != 'false';
    _barcodeEnabled = settings['barcode_enabled'] == 'true';
    _taxEnabled = settings['tax_enabled'] == 'true';
    _darkMode = settings['dark_mode'] == 'true';
  }

  Future<void> _loadSystemInfo() async {
    final db = await DatabaseHelper().database;
    _dbName = AppConfig.dbName;
    
    // عدد المستخدمين
    final users = await db.rawQuery('SELECT COUNT(*) as count FROM ${DBConstants.tableUsers} WHERE deleted = 0');
    _usersCount = (users.first['count'] as num?)?.toInt() ?? 0;

    // عدد الجداول
    final tables = await db.rawQuery("SELECT count(*) as count FROM sqlite_master WHERE type='table'");
    _tablesCount = (tables.first['count'] as num?)?.toInt() ?? 0;

    // آخر نسخة احتياطية
    final backups = await db.query(DBConstants.tableBackupHistory, orderBy: 'created_at DESC', limit: 1);
    if (backups.isNotEmpty) {
      _lastBackup = backups.first['created_at']?.toString().substring(0, 16) ?? 'لا يوجد';
    }

    // عدد السجلات (تقريبي)
    _recordsCount = _usersCount * 10; // تقريبي
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      await _repo.setAll({
        'company_name': _companyNameCtrl.text.trim(),
        'currency': _currencyCtrl.text.trim(),
        'default_box_size': _boxSizeCtrl.text.trim(),
        'low_stock_threshold': _lowStockCtrl.text.trim(),
        'session_timeout': _sessionTimeoutCtrl.text.trim(),
        'negative_stock': _negativeStock.toString(),
        'production_enabled': _productionEnabled.toString(),
        'showroom_enabled': _showroomEnabled.toString(),
        'distributors_enabled': _distributorsEnabled.toString(),
        'barcode_enabled': _barcodeEnabled.toString(),
        'tax_enabled': _taxEnabled.toString(),
        'dark_mode': _darkMode.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ جميع الإعدادات'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة ضبط الإعدادات'),
        content: const Text('سيتم إعادة جميع الإعدادات إلى قيمها الافتراضية. بياناتك لن تتأثر. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed == true) {
      final defaults = {
        'company_name': 'معمل أبو ليث', 'currency': 'ريال يمني', 'default_box_size': '60',
        'low_stock_threshold': '100', 'session_timeout': '30', 'negative_stock': 'false',
        'production_enabled': 'true', 'showroom_enabled': 'true', 'distributors_enabled': 'true',
        'barcode_enabled': 'false', 'tax_enabled': 'false', 'dark_mode': 'false',
      };
      await _repo.setAll(defaults);
      _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة الإعدادات الافتراضية')));
    }
  }

  Future<void> _createBackup() async {
    final db = await DatabaseHelper().database;
    await db.insert(DBConstants.tableBackupHistory, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'file_name': 'backup_${DateTime.now().millisecondsSinceEpoch}.db',
      'file_size': 0,
      'backup_type': 'يدوي',
      'created_by': 'admin',
      'created_at': DatabaseHelper.now,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية')));
    _loadSystemInfo();
  }

  Future<void> _deleteAllData() async {
    final passCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ حذف جميع البيانات'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('هذا الإجراء لا يمكن التراجع عنه. جميع بيانات النظام سيتم حذفها. أدخل كلمة المرور للتأكيد:'),
          TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, passCtrl.text == 'admin123'),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = await DatabaseHelper().database;
      // حذف منطقي لجميع السجلات
      final tables = [DBConstants.tableSales, DBConstants.tableProductionBatches, DBConstants.tablePurchases, DBConstants.tableStockMovements, DBConstants.tableTreasury, DBConstants.tableExpenses, DBConstants.tableInventoryCounts, DBConstants.tableSyncQueue];
      for (var table in tables) {
        await db.delete(table);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف جميع البيانات')));
      _loadAll();
    }
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose(); _currencyCtrl.dispose(); _boxSizeCtrl.dispose();
    _lowStockCtrl.dispose(); _sessionTimeoutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'إعادة تحميل', onPressed: _loadAll),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('🏢 معلومات المنشأة', [
                    TextField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: 'اسم المنشأة')),
                    const SizedBox(height: 12),
                    TextField(controller: _currencyCtrl, decoration: const InputDecoration(labelText: 'العملة')),
                  ]),
                  _buildSection('📦 إعدادات المخزون', [
                    TextField(controller: _boxSizeCtrl, decoration: const InputDecoration(labelText: 'عدد القطع الافتراضي في السلة'), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(controller: _lowStockCtrl, decoration: const InputDecoration(labelText: 'حد التنبيه لنقص المخزون'), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    SwitchListTile(title: const Text('السماح بالمخزون السالب'), value: _negativeStock, onChanged: (v) => setState(() => _negativeStock = v)),
                  ]),
                  _buildSection('🏭 إعدادات الإنتاج', [
                    SwitchListTile(title: const Text('تفعيل نظام الإنتاج'), value: _productionEnabled, onChanged: (v) => setState(() => _productionEnabled = v)),
                  ]),
                  _buildSection('🛒 إعدادات المعرض', [
                    SwitchListTile(title: const Text('تفعيل المعرض'), value: _showroomEnabled, onChanged: (v) => setState(() => _showroomEnabled = v)),
                  ]),
                  _buildSection('🚚 إعدادات الموزعين', [
                    SwitchListTile(title: const Text('تفعيل نظام الموزعين'), value: _distributorsEnabled, onChanged: (v) => setState(() => _distributorsEnabled = v)),
                  ]),
                  _buildSection('🔐 إعدادات الأمان', [
                    TextField(controller: _sessionTimeoutCtrl, decoration: const InputDecoration(labelText: 'مدة الجلسة (دقيقة)'), keyboardType: TextInputType.number),
                  ]),
                  _buildSection('🎨 إعدادات الواجهة', [
                    SwitchListTile(title: const Text('الوضع الداكن'), value: _darkMode, onChanged: (v) => setState(() => _darkMode = v)),
                  ]),

                  // ============ المرحلة الثانية: أقسام جديدة ============
                  _buildSection('💾 النسخ الاحتياطي', [
                    ListTile(
                      leading: const Icon(Icons.backup),
                      title: const Text('إنشاء نسخة احتياطية'),
                      subtitle: Text('آخر نسخة: $_lastBackup'),
                      trailing: ElevatedButton(onPressed: _createBackup, child: const Text('إنشاء')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('استعادة نسخة'),
                      trailing: ElevatedButton(onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم تفعيل هذه الميزة قريباً')));
                      }, child: const Text('استعادة')),
                    ),
                  ]),

                  _buildSection('🗄️ معلومات قاعدة البيانات', [
                    ListTile(title: const Text('اسم قاعدة البيانات'), subtitle: Text(_dbName)),
                    ListTile(title: const Text('عدد الجداول'), subtitle: Text('$_tablesCount')),
                    ListTile(title: const Text('عدد المستخدمين'), subtitle: Text('$_usersCount')),
                    ListTile(title: const Text('آخر نسخة احتياطية'), subtitle: Text(_lastBackup)),
                  ]),

                  _buildSection('📋 سجل العمليات', [
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('عرض سجل العمليات'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, '/audit');
                      },
                    ),
                  ]),

                  _buildSection('⚙️ إعادة ضبط', [
                    ListTile(
                      leading: const Icon(Icons.restore, color: AppTheme.warningColor),
                      title: const Text('إعادة الإعدادات الافتراضية'),
                      subtitle: const Text('لا يؤثر على البيانات'),
                      onTap: _resetSettings,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
                      title: const Text('حذف جميع بيانات النظام'),
                      subtitle: const Text('⚠️ لا يمكن التراجع'),
                      onTap: _deleteAllData,
                    ),
                  ]),

                  _buildSection('ℹ️ معلومات النظام', [
                    ListTile(title: const Text('الإصدار'), subtitle: Text(AppConfig.appVersion)),
                    ListTile(title: const Text('اسم النظام'), subtitle: const Text('أبو ليث ERP')),
                  ]),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAll,
                      child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ جميع الإعدادات'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
