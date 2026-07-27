import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ShowroomAccountScreen extends StatefulWidget {
  const ShowroomAccountScreen({super.key});

  @override
  State<ShowroomAccountScreen> createState() => _ShowroomAccountScreenState();
}

class _ShowroomAccountScreenState extends State<ShowroomAccountScreen> {
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    _movements = await db.query(DBConstants.tableShowroomMovements, orderBy: 'created_at DESC', limit: 100);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كشف حساب المعرض')),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty ? const Center(child: Text('لا توجد حركات'))
          : ListView.builder(itemCount: _movements.length, itemBuilder: (context, index) {
              final m = _movements[index];
              final isIn = (m['movement_type'] ?? '') == 'تحويل' || (m['movement_type'] ?? '') == 'مرتجع';
              return ListTile(
                leading: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? AppTheme.successColor : AppTheme.errorColor),
                title: Text(m['movement_type'] ?? ''),
                subtitle: Text(m['created_at'] ?? ''),
                trailing: Text('${m['quantity'] ?? 0}'),
              );
            }),
    );
  }
}
