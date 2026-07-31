import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
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

  // متحكمات الحقول
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
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

    setState(() => _isLoading = false);
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

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _currencyCtrl.dispose();
    _boxSizeCtrl.dispose();
    _lowStockCtrl.dispose();
    _sessionTimeoutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل الإعدادات',
            onPressed: _loadSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: '🏢 معلومات المنشأة',
                    children: [
                      TextField(controller: _companyNameCtrl, decoration: const InputDecoration(labelText: 'اسم المنشأة')),
                      const SizedBox(height: 12),
                      TextField(controller: _currencyCtrl, decoration: const InputDecoration(labelText: 'العملة')),
                    ],
                  ),
                  _buildSection(
                    title: '📦 إعدادات المخزون',
                    children: [
                      TextField(controller: _boxSizeCtrl, decoration: const InputDecoration(labelText: 'عدد القطع الافتراضي في السلة'), keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      TextField(controller: _lowStockCtrl, decoration: const InputDecoration(labelText: 'حد التنبيه لنقص المخزون'), keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      SwitchListTile(title: const Text('السماح بالمخزون السالب'), value: _negativeStock, onChanged: (v) => setState(() => _negativeStock = v)),
                    ],
                  ),
                  _buildSection(
                    title: '🏭 إعدادات الإنتاج',
                    children: [
                      SwitchListTile(title: const Text('تفعيل نظام الإنتاج'), value: _productionEnabled, onChanged: (v) => setState(() => _productionEnabled = v)),
                    ],
                  ),
                  _buildSection(
                    title: '🛒 إعدادات المعرض',
                    children: [
                      SwitchListTile(title: const Text('تفعيل المعرض'), value: _showroomEnabled, onChanged: (v) => setState(() => _showroomEnabled = v)),
                    ],
                  ),
                  _buildSection(
                    title: '🚚 إعدادات الموزعين',
                    children: [
                      SwitchListTile(title: const Text('تفعيل نظام الموزعين'), value: _distributorsEnabled, onChanged: (v) => setState(() => _distributorsEnabled = v)),
                    ],
                  ),
                  _buildSection(
                    title: '🔐 إعدادات الأمان',
                    children: [
                      TextField(controller: _sessionTimeoutCtrl, decoration: const InputDecoration(labelText: 'مدة الجلسة (دقيقة)'), keyboardType: TextInputType.number),
                    ],
                  ),
                  _buildSection(
                    title: '🎨 إعدادات الواجهة',
                    children: [
                      SwitchListTile(title: const Text('الوضع الداكن'), value: _darkMode, onChanged: (v) => setState(() => _darkMode = v)),
                    ],
                  ),
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

  Widget _buildSection({required String title, required List<Widget> children}) {
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
