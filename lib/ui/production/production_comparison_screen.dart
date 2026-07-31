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

  // متحكمات الإنتاج الفعلي
  Map<String, TextEditingController> _actualBoxesCtrl = {};
  Map<String, TextEditingController> _actualPiecesCtrl = {};
  Map<String, TextEditingController> _damagedCtrl = {};

  // متحكمات الإنتاج المطلوب
  Map<String, TextEditingController> _phasesCtrl = {};
  Map<String, TextEditingController> _piecesPerPhaseCtrl = {};

  bool _isLoading = true;
  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  // بيانات تاريخية تجريبية (ستستبدل بقاعدة البيانات لاحقاً)
  final List<Map<String, dynamic>> _historicalBatches = [
    {'date': '27/07', 'batch': 'B-0012', 'required': 8000, 'actual': 7960, 'lost': 40, 'damaged': 12, 'increase': 0},
    {'date': '28/07', 'batch': 'B-0015', 'required': 7800, 'actual': 7620, 'lost': 180, 'damaged': 35, 'increase': 0},
    {'date': '29/07', 'batch': 'B-0017', 'required': 8200, 'actual': 8210, 'lost': 0, 'damaged': 14, 'increase': 10},
    {'date': '30/07', 'batch': 'B-0018', 'required': 8400, 'actual': 8390, 'lost': 10, 'damaged': 12, 'increase': 0},
    {'date': '31/07', 'batch': 'B-0019', 'required': 8100, 'actual': 8125, 'lost': 0, 'damaged': 8, 'increase': 25},
  ];

  @override
  void initState() {
    super.initState();
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
        _actualBoxesCtrl[id] = TextEditingController(text: '0');
        _actualPiecesCtrl[id] = TextEditingController(text: '0');
        _damagedCtrl[id] = TextEditingController(text: '0');
        _phasesCtrl[id] = TextEditingController(text: '0');
        _piecesPerPhaseCtrl[id] = TextEditingController(text: '0');
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    for (var c in _actualBoxesCtrl.values) { c.dispose(); }
    for (var c in _actualPiecesCtrl.values) { c.dispose(); }
    for (var c in _damagedCtrl.values) { c.dispose(); }
    for (var c in _phasesCtrl.values) { c.dispose(); }
    for (var c in _piecesPerPhaseCtrl.values) { c.dispose(); }
    super.dispose();
  }

  // ============ دوال الحساب ============
  int _boxSize(String productId) {
    final product = _products.firstWhere((p) => p['id'] == productId);
    return product['pieces_per_box'] as int? ?? 60;
  }

  int _actualPiecesTotal(String productId) {
    final boxes = int.tryParse(_actualBoxesCtrl[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_actualPiecesCtrl[productId]?.text ?? '0') ?? 0;
    return (boxes * _boxSize(productId)) + pieces;
  }

  int _requiredPiecesTotal(String productId) {
    final phases = int.tryParse(_phasesCtrl[productId]?.text ?? '0') ?? 0;
    final perPhase = int.tryParse(_piecesPerPhaseCtrl[productId]?.text ?? '0') ?? 0;
    return phases * perPhase;
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.$remaining';
  }

  int _damaged(String productId) {
    return int.tryParse(_damagedCtrl[productId]?.text ?? '0') ?? 0;
  }

  // ============ مؤشرات الأداء ============
  int get _totalRequired => _products.fold(0, (sum, p) => sum + _requiredPiecesTotal(p['id']));
  int get _totalActual => _products.fold(0, (sum, p) => sum + _actualPiecesTotal(p['id']));
  int get _totalLost {
    int lost = 0;
    for (var p in _products) {
      final diff = _actualPiecesTotal(p['id']) - _requiredPiecesTotal(p['id']);
      if (diff < 0) lost += diff.abs();
    }
    return lost;
  }
  int get _totalDamaged => _products.fold(0, (sum, p) => sum + _damaged(p['id']));
  int get _totalIncrease {
    int inc = 0;
    for (var p in _products) {
      final diff = _actualPiecesTotal(p['id']) - _requiredPiecesTotal(p['id']);
      if (diff > 0) inc += diff;
    }
    return inc;
  }
  double get _avgMatch {
    if (_totalRequired == 0) return 0;
    return (_totalActual / _totalRequired) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مقارنة الإنتاجات وتحليل الضربات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // فلاتر
                  _buildFilters(),
                  const SizedBox(height: 12),
                  // مؤشرات الأداء
                  _buildKPIs(),
                  const SizedBox(height: 12),
                  // أعلى وأقل ضربة
                  _buildBestWorst(),
                  const SizedBox(height: 16),
                  // كشف المقارنة الحالي
                  _buildCurrentComparison(),
                  const SizedBox(height: 16),
                  // جدول تاريخي ورسوم بيانية
                  _buildHistoricalSection(),
                ],
              ),
            ),
    );
  }

  // ============ فلاتر ============
  Widget _buildFilters() {
    return Row(
      children: [
        const Text('من: '),
        SizedBox(width: 120, child: TextField(decoration: const InputDecoration(hintText: 'YYYY-MM-DD'), controller: TextEditingController(text: _selectedDate), onChanged: (v) => setState(() => _selectedDate = v))),
        const SizedBox(width: 8),
        const Text('إلى: '),
        SizedBox(width: 120, child: TextField(decoration: const InputDecoration(hintText: 'YYYY-MM-DD'), controller: TextEditingController(text: _selectedDate))),
        const SizedBox(width: 16),
        ElevatedButton(onPressed: () => setState(() {}), child: const Text('🔍 بحث')),
      ],
    );
  }

  // ============ مؤشرات الأداء ============
  Widget _buildKPIs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _kpiCard('إجمالي الضربات', '${_historicalBatches.length}', AppTheme.primaryColor),
        _kpiCard('إجمالي المطلوب', '${_totalRequired}', AppTheme.textPrimaryColor),
        _kpiCard('إجمالي الفعلي', '${_totalActual}', AppTheme.textPrimaryColor),
        _kpiCard('إجمالي الفاقد', '${_totalLost}', AppTheme.errorColor),
        _kpiCard('إجمالي التالف', '${_totalDamaged}', AppTheme.warningColor),
        _kpiCard('متوسط المطابقة', '${_avgMatch.toStringAsFixed(2)}%', AppTheme.successColor),
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

  // ============ أعلى وأقل ضربة ============
  Widget _buildBestWorst() {
    final best = _historicalBatches.reduce((a, b) => (a['actual'] / a['required']) > (b['actual'] / b['required']) ? a : b);
    final worst = _historicalBatches.reduce((a, b) => (a['actual'] / a['required']) < (b['actual'] / b['required']) ? a : b);
    return Row(
      children: [
        Expanded(
          child: Card(
            color: AppTheme.successColor.withAlpha(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('🏆 أعلى ضربة', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${best['batch']} | ${((best['actual'] / best['required']) * 100).toStringAsFixed(2)}%'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: AppTheme.errorColor.withAlpha(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('⚠️ أقل ضربة', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${worst['batch']} | فاقد: ${worst['lost']} | تالف: ${worst['damaged']}'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============ كشف المقارنة الحالي ============
  Widget _buildCurrentComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 كشف مقارنة الضربة الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildActualTable()),
                const SizedBox(width: 8),
                Expanded(child: _buildRequiredTable()),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultTable(),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(onPressed: () => setState(() {}), child: const Text('🔄 تحديث الحسابات')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم اعتماد الضربة!'))), child: const Text('✓ اعتماد الضربة')),
              ],
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
        const Text('📤 الإنتاج الفعلي', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [
            DataColumn(label: Text('المنتج')),
            DataColumn(label: Text('سلة')),
            DataColumn(label: Text('سلال')),
            DataColumn(label: Text('قطع')),
            DataColumn(label: Text('تالف')),
            DataColumn(label: Text('سليم')),
          ],
          rows: _products.map((p) {
            final id = p['id'] as String;
            final boxSize = _boxSize(id);
            final total = _actualPiecesTotal(id);
            return DataRow(cells: [
              DataCell(Text(p['name'] ?? '')),
              DataCell(Text('$boxSize')),
              DataCell(SizedBox(width: 50, child: TextField(controller: _actualBoxesCtrl[id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
              DataCell(SizedBox(width: 50, child: TextField(controller: _actualPiecesCtrl[id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
              DataCell(SizedBox(width: 50, child: TextField(controller: _damagedCtrl[id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
              DataCell(Text('$total', style: const TextStyle(fontWeight: FontWeight.bold))),
            ]);
          }).toList(),
        )),
      ],
    );
  }

  Widget _buildRequiredTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📥 الإنتاج المطلوب', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [
            DataColumn(label: Text('المنتج')),
            DataColumn(label: Text('أطوار')),
            DataColumn(label: Text('قطع/طور')),
            DataColumn(label: Text('المطلوب')),
            DataColumn(label: Text('سلال+قطع')),
          ],
          rows: _products.map((p) {
            final id = p['id'] as String;
            final boxSize = _boxSize(id);
            final required = _requiredPiecesTotal(id);
            return DataRow(cells: [
              DataCell(Text(p['name'] ?? '')),
              DataCell(SizedBox(width: 50, child: TextField(controller: _phasesCtrl[id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
              DataCell(SizedBox(width: 50, child: TextField(controller: _piecesPerPhaseCtrl[id], keyboardType: TextInputType.number, onChanged: (_) => setState(() {})))),
              DataCell(Text('$required', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_piecesToDisplay(required, boxSize))),
            ]);
          }).toList(),
        )),
      ],
    );
  }

  Widget _buildResultTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📊 نتيجة المقارنة', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [
            DataColumn(label: Text('المنتج')),
            DataColumn(label: Text('الفعلي (سلال+قطع)')),
            DataColumn(label: Text('المطلوب (سلال+قطع)')),
            DataColumn(label: Text('الفرق')),
            DataColumn(label: Text('الحالة')),
          ],
          rows: _products.map((p) {
            final id = p['id'] as String;
            final boxSize = _boxSize(id);
            final actual = _actualPiecesTotal(id);
            final required = _requiredPiecesTotal(id);
            final diff = actual - required;
            String status; Color color;
            if (diff > 0) { status = 'زيادة +$diff قطعة'; color = AppTheme.successColor; }
            else if (diff < 0) { status = 'فاقد $diff قطعة'; color = AppTheme.errorColor; }
            else { status = 'مطابق'; color = AppTheme.warningColor; }
            return DataRow(cells: [
              DataCell(Text(p['name'] ?? '')),
              DataCell(Text(_piecesToDisplay(actual, boxSize))),
              DataCell(Text(_piecesToDisplay(required, boxSize))),
              DataCell(Text('${diff >= 0 ? "+$diff" : "$diff"}', style: TextStyle(fontWeight: FontWeight.bold, color: color))),
              DataCell(Text(status, style: TextStyle(color: color))),
            ]);
          }).toList(),
        )),
        const SizedBox(height: 8),
        Text('الإجمالي: المطلوب $_totalRequired | الفعلي $_totalActual | الفاقد $_totalLost | التالف $_totalDamaged | الزيادة $_totalIncrease'),
      ],
    );
  }

  // ============ جدول تاريخي ورسوم بيانية ============
  Widget _buildHistoricalSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📈 تحليل أداء الضربات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              columns: const [
                DataColumn(label: Text('التاريخ')),
                DataColumn(label: Text('الضربة')),
                DataColumn(label: Text('المطلوب')),
                DataColumn(label: Text('الفعلي')),
                DataColumn(label: Text('الفاقد')),
                DataColumn(label: Text('التالف')),
                DataColumn(label: Text('الزيادة')),
                DataColumn(label: Text('المطابقة')),
              ],
              rows: _historicalBatches.map((b) {
                final match = ((b['actual'] / b['required']) * 100).toStringAsFixed(2);
                return DataRow(cells: [
                  DataCell(Text(b['date'])),
                  DataCell(Text(b['batch'])),
                  DataCell(Text('${b['required']}')),
                  DataCell(Text('${b['actual']}')),
                  DataCell(Text('${b['lost']}')),
                  DataCell(Text('${b['damaged']}')),
                  DataCell(Text('${b['increase']}')),
                  DataCell(Text('$match%')),
                ], onSelectChanged: (_) => _showBatchDetail(b));
              }).toList(),
            )),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _buildBarChart()),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: _buildLineChart()),
          ],
        ),
      ),
    );
  }

  void _showBatchDetail(Map<String, dynamic> batch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفاصيل الضربة ${batch['batch']}'),
        content: Text('المطلوب: ${batch['required']}\nالفعلي: ${batch['actual']}\nالفاقد: ${batch['lost']}\nالتالف: ${batch['damaged']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        barGroups: _historicalBatches.asMap().entries.map((e) {
          final i = e.key;
          final b = e.value;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: b['required'].toDouble(), color: AppTheme.primaryColor, width: 6),
            BarChartRodData(toY: b['actual'].toDouble(), color: AppTheme.successColor, width: 6),
            BarChartRodData(toY: b['lost'].toDouble(), color: AppTheme.errorColor, width: 6),
            BarChartRodData(toY: b['damaged'].toDouble(), color: AppTheme.warningColor, width: 6),
          ]);
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(_historicalBatches[v.toInt()]['batch'], style: const TextStyle(fontSize: 10)))),
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: _historicalBatches.asMap().entries.map((e) => FlSpot(e.key.toDouble(), ((e.value['actual'] / e.value['required']) * 100))).toList(),
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 2,
            dotData: FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(_historicalBatches[v.toInt()]['batch'], style: const TextStyle(fontSize: 10)))),
        ),
      ),
    );
  }
}
