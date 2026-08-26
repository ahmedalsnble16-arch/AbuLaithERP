import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/system_management_repository.dart';

class DataDeletionScreen extends StatefulWidget {
  const DataDeletionScreen({super.key});

  @override
  State<DataDeletionScreen> createState() => _DataDeletionScreenState();
}

class _DataDeletionScreenState extends State<DataDeletionScreen> {
  final SystemManagementRepository _repo = SystemManagementRepository();
  List<String> _tables = [];
  Map<String, int> _recordCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tables = await _repo.getTablesList();
    final counts = <String, int>{};
    for (var table in tables) {
      counts[table] = await _repo.getRecordCount(table);
    }
    setState(() {
      _tables = tables;
      _recordCounts = counts;
      _isLoading = false;
    });
  }

  Future<void> _showClearDialog(String tableName, int recordCount) async {
    final passwordCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تصفير $tableName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سيتم تصفير $recordCount سجل. البيانات ستؤرشف قبل التصفير.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة مرور المدير *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              try {
                await _repo.clearTable(
                  tableName: tableName,
                  adminPassword: passwordCtrl.text,
                  notes: notesCtrl.text,
                );
                Navigator.pop(ctx, true);
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorColor),
                );
              }
            },
            child: const Text('تأكيد التصفير'),
          ),
        ],
      ),
    );

    if (confirmed == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _tables.length,
            itemBuilder: (context, index) {
              final table = _tables[index];
              final count = _recordCounts[table] ?? 0;
              return Card(
                child: ListTile(
                  leading: Icon(
                    count > 0 ? Icons.table_chart : Icons.table_chart_outlined,
                    color: count > 0 ? AppTheme.warningColor : AppTheme.textSecondaryColor,
                  ),
                  title: Text(table),
                  subtitle: Text('عدد السجلات: $count'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
                    onPressed: count > 0 ? () => _showClearDialog(table, count) : null,
                  ),
                ),
              );
            },
          );
  }
}
