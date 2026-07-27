import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final SyncService _syncService = SyncService();
  int _pendingCount = 0;
  bool _isSyncing = false;
  String _statusMessage = '';
  bool _hasInternet = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    _hasInternet = await _syncService.hasInternet();
    _pendingCount = await _syncService.getPendingCount();
    setState(() {});
  }

  Future<void> _syncNow() async {
    setState(() { _isSyncing = true; _statusMessage = 'جاري المزامنة...'; });
    final result = await _syncService.syncAll();
    setState(() {
      _isSyncing = false;
      _statusMessage = result['success'] == true ? 'تمت المزامنة بنجاح' : 'حدث خطأ أثناء المزامنة';
    });
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المزامنة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(child: ListTile(leading: Icon(Icons.wifi, color: _hasInternet ? AppTheme.successColor : AppTheme.errorColor), title: Text(_hasInternet ? 'متصل' : 'غير متصل'))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildInfoCard('عمليات معلقة', '$_pendingCount', AppTheme.warningColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildInfoCard('آخر مزامنة', 'قريباً', AppTheme.primaryColor)),
            ]),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _isSyncing ? null : _syncNow, icon: _isSyncing ? const CircularProgressIndicator() : const Icon(Icons.sync), label: Text(_isSyncing ? 'جاري المزامنة...' : 'مزامنة الآن')),
            if (_statusMessage.isNotEmpty) ...[const SizedBox(height: 16), Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_statusMessage, textAlign: TextAlign.center)))],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Text(title, style: const TextStyle(fontSize: 12)), const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    ])));
  }
}
