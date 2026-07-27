import 'package:flutter/material.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    _logs = await db.query(DBConstants.tableAuditLogs, orderBy: 'created_at DESC', limit: 200);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل العمليات')),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty ? const Center(child: Text('لا توجد عمليات'))
          : ListView.builder(itemCount: _logs.length, itemBuilder: (context, index) {
              final log = _logs[index];
              return Card(child: ListTile(title: Text('${log['module']} - ${log['action']}'), subtitle: Text(log['created_at'] ?? '')));
            }),
    );
  }
}
