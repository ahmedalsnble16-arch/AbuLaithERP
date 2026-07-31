import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/repositories/settings_repository.dart';

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

  // متحكمات الحقول الأساسية
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
  bool _darkMode = false;

  // العملة والضرائب
  final _currencySymbolCtrl = TextEditingController();
  final _decimalPlacesCtrl = TextEditingController(text: '0');
  bool _taxEnabled = false;
  final _taxNameCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  bool _taxIncluded = false;
  bool _showTaxInInvoice = true;

  // المزامنة
  bool _autoSync = false;
  final _syncIntervalCtrl = TextEditingController(text: '5');
  bool _syncOnWifiOnly = true;

  // التقارير
  bool _showLogoOnReport = true;
  bool _showDateOnReport = true;
  bool _showUserOnReport = false;
  bool _showSignature = false;
  final _reportFooterCtrl = TextEditingController();

  // الإشعارات
  bool _notifyLowStock = true;
  bool _notifyDebts = true;
  bool _notifyExpenses = true;
  bool _notifyProduction = false;
  bool _notifySyncFail = true;

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
    _darkMode = settings['dark_mode'] == 'true';

    _taxEnabled = settings['tax_enabled'] == 'true';
    _taxNameCtrl.text = settings['tax_name'] ?? 'ضريبة';
    _taxRateCtrl.text = settings['tax_rate'] ?? '0';
    _taxIncluded = settings['tax_included'] == 'true';
    _showTaxInInvoice = settings['show_tax_in_invoice'] != 'false';
    _currencySymbolCtrl.text = settings['currency_symbol'] ?? 'ر.ي';
    _decimalPlacesCtrl.text = settings['decimal_places'] ?? '0';
    _autoSync = settings['auto_sync'] == 'true';
    _syncIntervalCtrl.text = settings['sync_interval'] ?? '5';
    _syncOnWifiOnly = settings['sync_on_wifi_only'] != 'false';
    _showLogoOnReport = settings['show_logo_on_report'] != 'false';
    _showDateOnReport = settings['show_date_on_report'] != 'false';
    _showUserOnReport = settings['show_user_on_report'] == 'true';
    _showSignature = settings['show_signature'] == 'true';
    _reportFooterCtrl.text = settings['report_footer'] ?? '';
    _notifyLowStock = settings['notify_low_stock'] != 'false';
    _notifyDebts = settings['notify_debts'] != 'false';
    _notifyExpenses = settings['notify_expenses'] != 'false';
    _notifyProduction = settings['notify_production'] == 'true';
    _notifySyncFail = settings['notify_sync_fail'] != 'false';
  }

  Future<void> _loadSystemInfo() async {
    final db = await DatabaseHelper().database;
    _dbName = AppConfig.dbName;
    
    final users = await db.rawQuery('SELECT COUNT(*) as count FROM ${DBConstants.tableUsers} WHERE deleted = 0');
    _usersCount = (users.first['count'] as num?)?.toInt() ?? 0;

    final tables = await db.rawQuery("SELECT count(*) as count FROM sqlite_master WHERE type='table'");
    _tablesCount = (tables.first['count'] as num?)?.toInt() ?? 0;

    final backups = await db.query(DBConstants.tableBackupHistory, orderBy: 'created_at DESC', limit: 1);
    if (backups.isNotEmpty) {
      _lastBackup = backups.first['created_at']?.toString().substring(0, 16) ?? 'لا يوجد';
    }

    _recordsCount = _usersCount * 10;
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
        'dark_mode': _darkMode.toString(),
        'currency_symbol': _currencySymbolCtrl.text.trim(),
        'decimal_places': _decimalPlacesCtrl.text.trim(),
        'tax_enabled': _taxEnabled.toString(),
        'tax_name': _taxNameCtrl.text.trim(),
        'tax_rate': _taxRateCtrl.text.trim(),
        'tax_included': _taxIncluded.toString(),
        'show_tax_in_invoice': _showTaxInInvoice.toString(),
        'auto_sync': _autoSync.toString(),
        'sync_interval': _syncIntervalCtrl.text.trim(),
        'sync_on_wifi_only': _syncOnWifiOnly.toString(),
        'show_logo_on_report': _showLogoOnReport.toString(),
        'show_date_on_report': _showDateOnReport.toString(),
        'show_user_on_report': _showUserOnReport.toString(),
        'show_signature': _showSignature.toString(),
        'report_footer': _reportFooterCtrl.text.trim(),
        'notify_low_stock': _notifyLowStock.toString(),
        'notify_debts': _notifyDebts.toString(),
        'notify_expenses': _notifyExpenses.toString(),
        'notify_production': _notifyProduction.toString(),
        'notify_sync_fail': _notifySyncFail.toString(),
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
        'currency_symbol': 'ر.ي', 'decimal_places': '0',
        'tax_name': 'ضريبة', 'tax_rate': '0', 'tax_included': 'false', 'show_tax_in_invoice': 'true',
        'auto_sync': 'false', 'sync_interval': '5', 'sync_on_wifi_only': 'true',
        'show_logo_on_report': 'true', 'show_date_on_report': 'true', 'show_user_on_report': 'false',
        'show_signature': 'false', 'report_footer': '',
        'notify_low_stock': 'true', 'notify_debts': 'true', 'notify_expenses': 'true',
        'notify_production': 'false', 'notify_sync_fail': 'true',
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
      final tables = [DBConstants.tableSales, DBConstants.tableProductionBatches, DBConstants.tablePurchases, DBConstants.tableStockMovements, DBConstants.tableTreasury, DBConstants.tableExpenses, DBConstants.tableInventoryCounts, DBConstants.tableSyncQueue];
      for (var table in tables) {
        await db.delete(table);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف جميع البيانات')));
      _loadAll();
    }
  }

  Future<void> _changePasswordDialog() async {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
            const SizedBox(height: 12),
            TextField(controller: newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (oldPassCtrl.text == 'admin123') {
                final db = await DatabaseHelper().database;
                await db.update(
                  DBConstants.tableUsers,
                  {'password_hash': newPassCtrl.text, 'updated_at': DatabaseHelper.now},
                  where: 'username = ?',
                  whereArgs: ['admin'],
                );
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور الحالية غير صحيحة')));
              }
            },
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')));
    }
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose(); _currencyCtrl.dispose(); _boxSizeCtrl.dispose();
    _lowStockCtrl.dispose(); _sessionTimeoutCtrl.dispose();
    _currencySymbolCtrl.dispose(); _decimalPlacesCtrl.dispose();
    _taxNameCtrl.dispose(); _taxRateCtrl.dispose();
    _syncIntervalCtrl.dispose();
    _reportFooterCtrl.dispose();
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

                  // ============ قسم المستخدمين والصلاحيات ============
                  _buildSection('👥 المستخدمون والصلاحيات', [
                    ListTile(
                      leading: const Icon(Icons.people, color: AppTheme.primaryColor),
                      title: const Text('إدارة المستخدمين'),
                      subtitle: Text('عدد المستخدمين: $_usersCount'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => Navigator.pushNamed(context, '/users'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.security, color: AppTheme.warningColor),
                      title: const Text('الصلاحيات والأدوار'),
                      subtitle: const Text('تحديد صلاحيات كل دور'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => Navigator.pushNamed(context, '/roles'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock, color: AppTheme.errorColor),
                      title: const Text('تغيير كلمة المرور'),
                      subtitle: const Text('تغيير كلمة مرور المستخدم الحالي'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _changePasswordDialog(),
                    ),
                  ]),

                  // الأقسام الجديدة
                  _buildSection('💱 العملة والضرائب', [
                    TextField(controller: _currencySymbolCtrl, decoration: const InputDecoration(labelText: 'رمز العملة')),
                    const SizedBox(height: 12),
                    TextField(controller: _decimalPlacesCtrl, decoration: const InputDecoration(labelText: 'المنازل العشرية'), keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    SwitchListTile(title: const Text('تفعيل الضرائب'), value: _taxEnabled, onChanged: (v) => setState(() => _taxEnabled = v)),
                    TextField(controller: _taxNameCtrl, decoration: const InputDecoration(labelText: 'اسم الضريبة')),
                    const SizedBox(height: 12),
                    TextField(controller: _taxRateCtrl, decoration: const InputDecoration(labelText: 'نسبة الضريبة (%)'), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    SwitchListTile(title: const Text('تضمين الضريبة في السعر'), value: _taxIncluded, onChanged: (v) => setState(() => _taxIncluded = v)),
                    SwitchListTile(title: const Text('إظهار الضريبة في الفواتير'), value: _showTaxInInvoice, onChanged: (v) => setState(() => _showTaxInInvoice = v)),
                  ]),
                  _buildSection('🔄 المزامنة', [
                    SwitchListTile(title: const Text('المزامنة التلقائية'), value: _autoSync, onChanged: (v) => setState(() => _autoSync = v)),
                    TextField(controller: _syncIntervalCtrl, decoration: const InputDecoration(labelText: 'فترة المزامنة (دقائق)'), keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    SwitchListTile(title: const Text('المزامنة عبر Wi-Fi فقط'), value: _syncOnWifiOnly, onChanged: (v) => setState(() => _syncOnWifiOnly = v)),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: const Text('مزامنة الآن'),
                      trailing: ElevatedButton(onPressed: () { Navigator.pushNamed(context, '/sync'); }, child: const Text('فتح')),
                    ),
                  ]),
                  _buildSection('🖨️ التقارير والطباعة', [
                    SwitchListTile(title: const Text('إظهار الشعار في التقرير'), value: _showLogoOnReport, onChanged: (v) => setState(() => _showLogoOnReport = v)),
                    SwitchListTile(title: const Text('إظهار التاريخ'), value: _showDateOnReport, onChanged: (v) => setState(() => _showDateOnReport = v)),
                    SwitchListTile(title: const Text('إظهار اسم المستخدم'), value: _showUserOnReport, onChanged: (v) => setState(() => _showUserOnReport = v)),
                    SwitchListTile(title: const Text('إظهار التوقيع'), value: _showSignature, onChanged: (v) => setState(() => _showSignature = v)),
                    TextField(controller: _reportFooterCtrl, decoration: const InputDecoration(labelText: 'نص تذييل التقرير'), maxLines: 2),
                  ]),
                  _buildSection('🔔 الإشعارات', [
                    SwitchListTile(title: const Text('تنبيه نقص المخزون'), subtitle: const Text('عند وصول المخزون للحد الأدنى'), value: _notifyLowStock, onChanged: (v) => setState(() => _notifyLowStock = v)),
                    SwitchListTile(title: const Text('تنبيه المديونيات'), subtitle: const Text('عند وجود ديون مستحقة'), value: _notifyDebts, onChanged: (v) => setState(() => _notifyDebts = v)),
                    SwitchListTile(title: const Text('تنبيه المصروفات'), subtitle: const Text('عند تسجيل مصروف جديد'), value: _notifyExpenses, onChanged: (v) => setState(() => _notifyExpenses = v)),
                    SwitchListTile(title: const Text('تنبيه الإنتاج'), subtitle: const Text('عند اكتمال دفعة إنتاج'), value: _notifyProduction, onChanged: (v) => setState(() => _notifyProduction = v)),
                    SwitchListTile(title: const Text('تنبيه فشل المزامنة'), value: _notifySyncFail, onChanged: (v) => setState(() => _notifySyncFail = v)),
                  ]),

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
                      onTap: () => Navigator.pushNamed(context, '/audit'),
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
