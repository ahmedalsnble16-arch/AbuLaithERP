import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ProductionComparisonScreen extends StatefulWidget {
  const ProductionComparisonScreen({super.key});

  @override
  State<ProductionComparisonScreen> createState() => _ProductionComparisonScreenState();
}

class _ProductionComparisonScreenState extends State<ProductionComparisonScreen> {
  List<Map<String, dynamic>> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final data = await db.rawQuery('''
      SELECT pb.*, p.name as product_name, p.pieces_per_box
      FROM ${DBConstants.tableProductionBatches} pb
      JOIN ${DBConstants.tableProducts} p ON pb.product_id = p.id
      WHERE pb.deleted = 0
      ORDER BY pb.production_date DESC
      LIMIT 50
    ''');
    setState(() { _batches = data; _isLoading = false; });
  }

  Color _getColor(double lossPercent) {
    if (lossPercent <= 2) return AppTheme.successColor;
    if (lossPercent <= 5) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _batches.isEmpty
            ? const Center(child: Text('لا توجد بيانات'))
            : ListView.builder(
                itemCount: _batches.length,
                itemBuilder: (context, index) {
                  final b = _batches[index];
                  final expected = b['expected_pieces'] as int? ?? 0;
                  final good = b['good_pieces'] as int? ?? 0;
                  final damaged = b['damaged_pieces'] as int? ?? 0;
                  final lost = b['lost_pieces'] as int? ?? 0;
                  final loss = damaged + lost;
                  final lossPercent = expected > 0 ? (loss / expected) * 100 : 0;

                  return Card(
                    color: _getColor(lossPercent).withAlpha(20),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المنتج: ${b['product_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('المخطط:', style: TextStyle(color: Colors.blueGrey)),
                                  Text('القطع: $expected'),
                                ]),
                              ),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('الفعلي:', style: TextStyle(color: Colors.blueGrey)),
                                  Text('صالح: $good'),
                                  Text('تالف: $damaged'),
                                  Text('فاقد: $lost'),
                                ]),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text('نسبة الفاقد: ${lossPercent.toStringAsFixed(1)}%', style: TextStyle(color: _getColor(lossPercent), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              );
  }
}
