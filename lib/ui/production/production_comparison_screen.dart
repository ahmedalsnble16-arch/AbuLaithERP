import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class ProductionComparisonScreen extends StatefulWidget {
  const ProductionComparisonScreen({super.key});

  @override
  State<ProductionComparisonScreen> createState() => _ProductionComparisonScreenState();
}

class _ProductionComparisonScreenState extends State<ProductionComparisonScreen> {
  // بيانات المنتجات المستوردة من قاعدة البيانات
  List<Map<String, dynamic>> _products = [];

  // متحكمات الإنتاج المطلوب فقط (المدخلات اليدوية الوحيدة)
  final Map<String, TextEditingController> _phasesCtrl = {};
  final Map<String, TextEditingController> _piecesPerPhaseCtrl = {};

  // بيانات الإنتاج الفعلي المستوردة تلقائياً
  Map<String, int> _importedGoodPieces = {};
  Map<String, int> _importedDamagedPieces = {};

  bool _isLoading = true;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);
  String _batchNumber = '';
  bool _comparisonCalculated = false;
  bool _batchApproved = false;

  @override
  void initState() {
    super.initState();
    _batchNumber = 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;
    final products = await db.query(DBConstants.tableProducts, where: 'deleted = 0');
    setState(() {
      _products = products;
      for (var p in products) {
        final id = p['id'] as String;
        _phasesCtrl[id] = TextEditingController(text: '0');
        _piecesPerPhaseCtrl[id] = TextEditingController(text: '0');
        _importedGoodPieces[id] = 0;
        _importedDamagedPieces[id] = 0;
      }
      _isLoading = false;
    });

    // استيراد بيانات الإنتاج الفعلي تلقائياً
    await _importProductionData();
  }

  /// استيراد الإنتاج السليم والتالف من جدول production_batches تلقائياً
  Future<void> _importProductionData() async {
    final db = await DatabaseHelper().database;

    final batches = await db.query(
      DBConstants.tableProductionBatches,
      where: 'production_date = ? AND deleted = 0',
      whereArgs: [_selectedDate],
    );

    final goodMap = <String, int>{};
    final damagedMap = <String, int>{};

    for (var batch in batches) {
      final productId = batch['product_id'] as String;
      final good = batch['good_pieces'] as int? ?? 0;
      final damaged = batch['damaged_pieces'] as int? ?? 0;

      goodMap[productId] = (goodMap[productId] ?? 0) + good;
      damagedMap[productId] = (damagedMap[productId] ?? 0) + damaged;
    }

    setState(() {
      _importedGoodPieces = goodMap;
      _importedDamagedPieces = damagedMap;
    });
  }

  @override
  void dispose() {
    for (var c in _phasesCtrl.values) { c.dispose(); }
    for (var c in _piecesPerPhaseCtrl.values) { c.dispose(); }
    super.dispose();
  }

  // ============ دوال الحساب ============
  int _boxSize(String productId) {
    final product = _products.firstWhere((p) => p['id'] == productId);
    return product['pieces_per_box'] as int? ?? 60;
  }

  int _actualGoodPieces(String productId) {
    return _importedGoodPieces[productId] ?? 0;
  }

  int _damagedPieces(String productId) {
    return _importedDamagedPieces[productId] ?? 0;
  }

  int _requiredPiecesTotal(String productId) {
    final phases = int.tryParse(_phasesCtrl[productId]?.text ?? '0') ?? 0;
    final perPhase = int.tryParse(_piecesPerPhaseCtrl[productId]?.text ?? '0') ?? 0;
    return phases * perPhase;
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    if (boxSize <= 0) return '$pieces';
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.$remaining';
  }

  // ============ مؤشرات الأداء ============
  int get _totalRequired => _products.fold(0, (sum, p) => sum + _requiredPiecesTotal(p['id']));
  int get _totalActualGood => _products.fold(0, (sum, p) => sum + _actualGoodPieces(p['id']));
  int get _totalDamaged => _products.fold(0, (sum, p) => sum + _damagedPieces(p['id']));
  int get _totalLost {
    int lost = 0;
    for (var p in _products) {
      final diff = _actualGoodPieces(p['id']) - _requiredPiecesTotal(p['id']);
      if (diff < 0) lost += diff.abs();
    }
    return lost;
  }
  int get _totalIncrease {
    int inc = 0;
    for (var p in _products) {
      final diff = _actualGoodPieces(p['id']) - _requiredPiecesTotal(p['id']);
      if (diff > 0) inc += diff;
    }
    return inc;
  }
  double get _avgMatch {
    if (_totalRequired == 0) return 0;
    return (_totalActualGood / _totalRequired) * 100;
  }

  void _calculateComparison() {
    setState(() {
      _comparisonCalculated = true;
      _batchApproved = false;
    });
  }

  void _approveBatch() {
    setState(() {
      _batchApproved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم اعتماد الضربة وتثبيت النتائج'), backgroundColor: AppTheme.successColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مقارنة الإنتاجات وتحليل الضربات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _importProductionData,
            tooltip: 'إعادة استيراد بيانات الإنتاج',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رأس الكشف
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text('مقارنة الضربة رقم: $_batchNumber', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'التاريخ', hintText: 'YYYY-MM-DD'),
                                  controller: TextEditingController(text: _selectedDate),
                                  onSubmitted: (v) {
                                    _selectedDate = v;
                                    _importProductionData();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(child: TextField(decoration: InputDecoration(labelText: 'مسؤول الإنتاج'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // مؤشرات الأداء
                  _buildKPIs(),
                  const SizedBox(height: 16),

                  // كشف المقارنة
                  _buildCurrentComparison(),
                ],
              ),
            ),
    );
  }

  // ============ مؤشرات الأداء ============
  Widget _buildKPIs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _kpiCard('إجمالي المطلوب', '${_totalRequired}', AppTheme.textPrimaryColor),
        _kpiCard('إجمالي الفعلي السليم (مستورد)', '${_totalActualGood}', AppTheme.successColor),
        _kpiCard('إجمالي التالف (مستورد)', '${_totalDamaged}', AppTheme.warningColor),
        _kpiCard('الفاقد', '${_totalLost}', AppTheme.errorColor),
        _kpiCard('الزيادة', '${_totalIncrease}', AppTheme.successColor),
        _kpiCard('متوسط المطابقة', '${_avgMatch.toStringAsFixed(2)}%', AppTheme.primaryColor),
      ],
    );
  }

  Widget _kpiCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ============ كشف المقارنة ============
  Widget _buildCurrentComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildActualTable()),
                const SizedBox(width: 8),
                Expanded(child: _buildRequiredTable()),
              ],
            ),
            const SizedBox(height: 16),
            if (_comparisonCalculated) _buildResultTable(),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _calculateComparison,
              icon: const Icon(Icons.calculate),
              label: const Text('حساب المقارنة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActualTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📤 الإنتاج الفعلي (مستورد تلقائياً)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المنتج')),
              DataColumn(label: Text('سلة')),
              DataColumn(label: Text('سليم (سلال+قطع)')),
              DataColumn(label: Text('سليم (قطع)')),
              DataColumn(label: Text('تالف (سلال+قطع)')),
              DataColumn(label: Text('تالف (قطع)')),
            ],
            rows: _products.map((p) {
              final id = p['id'] as String;
              final boxSize = _boxSize(id);
              final good = _actualGoodPieces(id);
              final damaged = _damagedPieces(id);
              return DataRow(cells: [
                DataCell(Text(p['name'] ?? '')),
                DataCell(Text('$boxSize')),
                DataCell(Text(_piecesToDisplay(good, boxSize), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.successColor))),
                DataCell(Text('$good')),
                DataCell(Text(_piecesToDisplay(damaged, boxSize), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warningColor))),
                DataCell(Text('$damaged')),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRequiredTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📥 الإنتاج المطلوب (إدخال يدوي)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المنتج')),
              DataColumn(label: Text('أطوار')),
              DataColumn(label: Text('قطع/طور')),
              DataColumn(label: Text('المطلوب (قطع)')),
              DataColumn(label: Text('سلال مطلوبة')),
            ],
            rows: _products.map((p) {
              final id = p['id'] as String;
              final boxSize = _boxSize(id);
              final required = _requiredPiecesTotal(id);
              final reqDisplay = _piecesToDisplay(required, boxSize);
              return DataRow(cells: [
                DataCell(Text(p['name'] ?? '')),
                DataCell(SizedBox(width: 50, child: TextField(controller: _phasesCtrl[id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                DataCell(SizedBox(width: 50, child: TextField(controller: _piecesPerPhaseCtrl[id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
                DataCell(Text('$required', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(reqDisplay)),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('📊 نتيجة المقارنة', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('المنتج')),
              DataColumn(label: Text('الفعلي (سلال+قطع)')),
              DataColumn(label: Text('المطلوب (سلال+قطع)')),
              DataColumn(label: Text('التالف')),
              DataColumn(label: Text('الفرق')),
              DataColumn(label: Text('الحالة')),
            ],
            rows: _products.map((p) {
              final id = p['id'] as String;
              final boxSize = _boxSize(id);
              final actual = _actualGoodPieces(id);
              final required = _requiredPiecesTotal(id);
              final damaged = _damagedPieces(id);
              final diff = actual - required;
              String status;
              Color color;
              if (diff > 0) { status = 'زيادة +$diff قطعة'; color = AppTheme.successColor; }
              else if (diff < 0) { status = 'فاقد ${diff.abs()} قطعة'; color = AppTheme.errorColor; }
              else { status = 'مطابق'; color = AppTheme.warningColor; }
              return DataRow(cells: [
                DataCell(Text(p['name'] ?? '')),
                DataCell(Text(_piecesToDisplay(actual, boxSize))),
                DataCell(Text(_piecesToDisplay(required, boxSize))),
                DataCell(Text('$damaged')),
                DataCell(Text('${diff >= 0 ? "+$diff" : "$diff"}', style: TextStyle(fontWeight: FontWeight.bold, color: color))),
                DataCell(Text(status, style: TextStyle(color: color))),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'إجمالي المطلوب: $_totalRequired قطعة | إجمالي الفعلي السليم: $_totalActualGood قطعة | الفاقد: $_totalLost | التالف: $_totalDamaged | الزيادة: $_totalIncrease',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
