import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ProductionStatsScreen extends StatefulWidget {
  const ProductionStatsScreen({super.key});

  @override
  State<ProductionStatsScreen> createState() => _ProductionStatsScreenState();
}

class _ProductionStatsScreenState extends State<ProductionStatsScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = await DatabaseHelper().database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final todayData = await db.rawQuery('''
      SELECT COUNT(*) as count,
             COALESCE(SUM(expected_pieces),0) as total_expected,
             COALESCE(SUM(good_pieces),0) as total_good,
             COALESCE(SUM(damaged_pieces),0) as total_damaged,
             COALESCE(SUM(lost_pieces),0) as total_lost
      FROM ${DBConstants.tableProductionBatches}
      WHERE production_date = ? AND deleted = 0
    ''', [today]);

    setState(() {
      _stats = todayData.first;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalExpected = (_stats['total_expected'] as num?)?.toDouble() ?? 0;
    final totalGood = (_stats['total_good'] as num?)?.toDouble() ?? 0;
    final totalDamaged = (_stats['total_damaged'] as num?)?.toDouble() ?? 0;
    final totalLost = (_stats['total_lost'] as num?)?.toDouble() ?? 0;
    final totalWaste = totalDamaged + totalLost;
    final wastePercent = totalExpected > 0 ? (totalWaste / totalExpected) * 100 : 0;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(child: ListTile(title: const Text('عدد عمليات اليوم'), trailing: Text('${_stats['count'] ?? 0}'))),
                Card(child: ListTile(title: const Text('إجمالي القطع المتوقعة'), trailing: Text('${totalExpected.toInt()}'))),
                Card(child: ListTile(title: const Text('الإنتاج الصالح'), trailing: Text('${totalGood.toInt()}'))),
                Card(child: ListTile(title: const Text('التالف'), trailing: Text('${totalDamaged.toInt()}'))),
                Card(child: ListTile(title: const Text('الفاقد'), trailing: Text('${totalLost.toInt()}'))),
                Card(
                  color: wastePercent > 5 ? AppTheme.errorColor.withAlpha(30) : AppTheme.successColor.withAlpha(30),
                  child: ListTile(
                    title: const Text('نسبة الهدر'),
                    trailing: Text('${wastePercent.toStringAsFixed(1)}%', style: TextStyle(color: wastePercent > 5 ? AppTheme.errorColor : AppTheme.successColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
  }
}
