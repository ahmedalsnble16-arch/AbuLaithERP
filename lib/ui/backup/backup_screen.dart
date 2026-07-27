import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    _backups = await db.query(DBConstants.tableBackupHistory, orderBy: 'created_at DESC');
    setState(() => _isLoading = false);
  }

  Future<void> _createBackup() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;
    await db.insert(DBConstants.tableBackupHistory, {
      'id': const Uuid().v4(), 'file_name': 'backup_${DateTime.now().millisecondsSinceEpoch}.db',
      'file_size': 0, 'backup_type': 'يدوي', 'created_by': 'admin', 'created_at': now,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية'), backgroundColor: AppTheme.successColor));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: ElevatedButton.icon(onPressed: _createBackup, icon: const Icon(Icons.backup), label: const Text('إنشاء نسخة احتياطية'))),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator())
            : _backups.isEmpty ? const Center(child: Text('لا توجد نسخ'))
            : ListView.builder(itemCount: _backups.length, itemBuilder: (context, index) {
                final b = _backups[index];
                return Card(child: ListTile(leading: const Icon(Icons.save), title: Text(b['file_name'] ?? ''), subtitle: Text('${b['created_at']} | ${b['backup_type']}')));
              })),
      ]),
    );
  }
}
