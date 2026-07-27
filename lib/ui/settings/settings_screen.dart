import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(DBConstants.tableSettings);
    setState(() {
      _settings = {for (var m in maps) m['key'] as String: m['value'] as String};
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('بيانات الشركة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ListTile(title: const Text('اسم الشركة'), subtitle: Text(_settings['company_name'] ?? '')),
                ListTile(title: const Text('العملة'), subtitle: Text(_settings['currency'] ?? '')),
              ]))),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('النظام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ListTile(title: const Text('عدد القطع الافتراضي في السلة'), subtitle: Text(_settings['default_box_size'] ?? '60')),
                ListTile(title: const Text('حد التنبيه لنقص المخزون'), subtitle: Text(_settings['low_stock_threshold'] ?? '100')),
                ListTile(title: const Text('الإصدار'), subtitle: Text(AppConfig.appVersion)),
              ]))),
            ]),
    );
  }
}
