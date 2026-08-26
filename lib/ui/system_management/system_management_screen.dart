import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/system_management_repository.dart';
import 'data_deletion_screen.dart';
import 'dynamic_creation_screen.dart';

class SystemManagementScreen extends StatefulWidget {
  const SystemManagementScreen({super.key});

  @override
  State<SystemManagementScreen> createState() => _SystemManagementScreenState();
}

class _SystemManagementScreenState extends State<SystemManagementScreen> {
  final SystemManagementRepository _repo = SystemManagementRepository();
  int _tablesCount = 0;
  int _dynamicElementsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final tables = await _repo.getTablesList();
    final elements = await _repo.getDynamicElements();
    setState(() {
      _tablesCount = tables.length;
      _dynamicElementsCount = elements.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز إدارة النظام'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '🗑️ الحذف والإدارة'),
              Tab(text: '➕ الإنشاء والإضافة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DataDeletionScreen(),
            DynamicCreationScreen(),
          ],
        ),
      ),
    );
  }
}
