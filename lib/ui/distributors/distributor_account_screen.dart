import 'package:flutter/material.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/distributor.dart';
import '../../data/repositories/distributor_repository.dart';
import 'Distributor_Load_Detail_Screen.dart';

class DistributorAccountScreen extends StatefulWidget {
  final Distributor distributor;
  const DistributorAccountScreen({super.key, required this.distributor});

  @override
  State<DistributorAccountScreen> createState() => _DistributorAccountScreenState();
}

class _DistributorAccountScreenState extends State<DistributorAccountScreen> {
  final DistributorRepository _distRepo = DistributorRepository();
  late Distributor _currentDistributor;
  List<Map<String, dynamic>> _loads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentDistributor = widget.distributor;
    _loadLoads();
  }

  Future<void> _loadLoads() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    _loads = await db.query(
      DBConstants.tableDistributorLoads,
      where: 'distributor_id = ?',
      whereArgs: [_currentDistributor.id],
      orderBy: 'created_at DESC',
    );
    setState(() => _isLoading = false);
  }

  Future<void> _refreshDistributor() async {
    final refreshed = await _distRepo.getById(_currentDistributor.id);
    if (refreshed != null) {
      setState(() {
        _currentDistributor = refreshed;
      });
    }
  }

  Future<void> _createNewLoad() async {
    final db = await DatabaseHelper().database;
    final loadId = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert(DBConstants.tableDistributorLoads, {
      'id': loadId,
      'distributor_id': _currentDistributor.id,
      'load_date': DateTime.now().toIso8601String().substring(0, 10),
      'status': 'مفتوحة',
      'created_at': DatabaseHelper.now,
      'updated_at': DatabaseHelper.now,
    });
    await _loadLoads();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب: ${_currentDistributor.name}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _loads.length,
              itemBuilder: (context, index) {
                final load = _loads[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt),
                    title: Text('حملة ${load['load_date'] ?? ''}'),
                    subtitle: Text('الحالة: ${load['status']} | ${load['notes'] ?? ''}'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DistributorLoadDetailScreen(
                            distributor: _currentDistributor,
                            loadId: load['id'] as String,
                          ),
                        ),
                      );
                      // إعادة تحميل بيانات الموزع بعد العودة من تفاصيل الحملة
                      await _refreshDistributor();
                      _loadLoads();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewLoad,
        child: const Icon(Icons.add),
      ),
    );
  }
}
