import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/distributor.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_repository.dart';
import '../../data/repositories/distributor_product_price_repository.dart';
import '../../data/repositories/distributor_damage_repository.dart' as damageRepo;
import '../../data/repositories/distributor_return_repository.dart';

class DistributorLoadDetailScreen extends StatefulWidget {
  final Distributor distributor;
  final String loadId;
  const DistributorLoadDetailScreen({super.key, required this.distributor, required this.loadId});

  @override
  State<DistributorLoadDetailScreen> createState() => _DistributorLoadDetailScreenState();
}

class _DistributorLoadDetailScreenState extends State<DistributorLoadDetailScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DistributorRepository _distRepo = DistributorRepository();
  final DistributorProductPriceRepository _priceRepo = DistributorProductPriceRepository();
  final damageRepo.DistributorDamageRepository _damageRepo = damageRepo.DistributorDamageRepository();
  final DistributorReturnRepository _returnRepo = DistributorReturnRepository();

  List<Product> _products = [];
  Map<String, double> _prices = {};
  Map<String, double> _damagePrices = {};
  bool _isLoading = true;
  String? _loadDate;
  String? _loadStatus;

  final Map<String, TextEditingController> _boxesCtrl = {};
  final Map<String, TextEditingController> _piecesCtrl = {};
  double _totalLoadValue = 0;

  double _totalReturnedValue = 0;
  final Map<String, int> _returnBoxes = {};
  final Map<String, int> _returnPieces = {};
  final Map<String, int> _oldReturnPieces = {};

  double _totalDamagedValue = 0;
  int _damageSmall = 0, _damageLarge = 0, _damageTamer = 0;

  final TextEditingController _cashCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepo.getAll();
      _products = products.where((p) => p.active).toList();

      _prices = await _priceRepo.getPricesForDistributor(widget.distributor.id);
      _damagePrices = await _damageRepo.getDamagePrices(widget.distributor.id);

      final db = await DatabaseHelper().database;
      final loadData = await db.query(DBConstants.tableDistributorLoads,
          where: 'id = ?', whereArgs: [widget.loadId]);
      if (loadData.isNotEmpty) {
        _loadDate = loadData.first['load_date']?.toString();
        _loadStatus = loadData.first['status']?.toString();
      }

      for (var p in _products) {
        _boxesCtrl[p.id] = TextEditingController(text: '0');
        _piecesCtrl[p.id] = TextEditingController(text: '0');
      }

      final items = await _distRepo.getLoadItems(widget.loadId);
      for (var item in items) {
        final pid = item['product_id'] as String;
        final qty = item['quantity'] as int;
        final p = _products.firstWhere((x) => x.id == pid);
        _boxesCtrl[pid]?.text = (qty ~/ p.piecesPerBox).toString();
        _piecesCtrl[pid]?.text = (qty % p.piecesPerBox).toString();
      }

      final returns = await db.query(DBConstants.tableDistributorLoadReturns,
          where: 'load_id = ?', whereArgs: [widget.loadId]);
      for (var r in returns) {
        final pid = r['product_id'] as String;
        _returnBoxes[pid] = r['boxes'] as int? ?? 0;
        _returnPieces[pid] = r['pieces'] as int? ?? 0;
        final p = _products.firstWhere((x) => x.id == pid);
        final totalPieces = (_returnBoxes[pid]! * p.piecesPerBox) + _returnPieces[pid]!;
        _oldReturnPieces[pid] = totalPieces;
        _totalReturnedValue += totalPieces * (_prices[pid] ?? p.wholesalePrice);
      }

      final damages = await db.query(DBConstants.tableDistributorLoadDamage,
          where: 'load_id = ?', whereArgs: [widget.loadId]);
      for (var d in damages) {
        final type = d['damage_type'] as String;
        final pieces = d['pieces'] as int? ?? 0;
        if (type == 'صغير') _damageSmall = pieces;
        if (type == 'كبير') _damageLarge = pieces;
        if (type == 'تمرية كبير') _damageTamer = pieces;
      }
      _calculateDamageValue();
      _calculateTotals();
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  double _getPrice(String pid) =>
      _prices[pid] ?? _products.firstWhere((x) => x.id == pid).wholesalePrice;

  void _calculateTotals() {
    double val = 0;
    for (var p in _products) {
      final boxes = int.tryParse(_boxesCtrl[p.id]?.text ?? '') ?? 0;
      final pieces = int.tryParse(_piecesCtrl[p.id]?.text ?? '') ?? 0;
      val += (boxes * p.piecesPerBox + pieces) * _getPrice(p.id);
    }
    _totalLoadValue = val;
  }

  Future<void> _saveLoad() async {
    final items = <Map<String, dynamic>>[];
    for (var p in _products) {
      final boxes = int.tryParse(_boxesCtrl[p.id]?.text ?? '') ?? 0;
      final pieces = int.tryParse(_piecesCtrl[p.id]?.text ?? '') ?? 0;
      final qty = boxes * p.piecesPerBox + pieces;
      if (qty > 0) items.add({'productId': p.id, 'quantity': qty, 'unitPrice': _getPrice(p.id)});
    }
    if (items.isEmpty) return;

    final db = await DatabaseHelper().database;
    await db.delete(DBConstants.tableDistributorLoadItems,
        where: 'load_id = ?', whereArgs: [widget.loadId]);
    for (var item in items) {
      await db.insert(DBConstants.tableDistributorLoadItems, {
        'id': const Uuid().v4(),
        'load_id': widget.loadId,
        'product_id': item['productId'],
        'quantity': item['quantity'],
        'unit_price': item['unitPrice'],
        'created_at': DatabaseHelper.now,
      });
    }
    _showMsg('تم حفظ التحميل', success: true);
  }

  Future<void> _openReturnsDialog() async {
    final tempBoxes = Map<String, int>.from(_returnBoxes);
    final tempPieces = Map<String, int>.from(_returnPieces);
    final boxCtrl = <String, TextEditingController>{};
    final pieceCtrl = <String, TextEditingController>{};

    for (var p in _products) {
      boxCtrl[p.id] = TextEditingController(text: (tempBoxes[p.id] ?? 0).toString());
      pieceCtrl[p.id] = TextEditingController(text: (tempPieces[p.id] ?? 0).toString());
    }

    final result = await showDialog<Map<String, Map<String, int>>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('مرتجعات الحملة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _products.map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(p.name)),
                        Expanded(
                          child: TextField(
                            controller: boxCtrl[p.id],
                            decoration: const InputDecoration(labelText: 'سلال', isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: pieceCtrl[p.id],
                            decoration: const InputDecoration(labelText: 'قطع', isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final boxes = <String, int>{};
                final pieces = <String, int>{};
                for (var p in _products) {
                  boxes[p.id] = int.tryParse(boxCtrl[p.id]?.text ?? '') ?? 0;
                  pieces[p.id] = int.tryParse(pieceCtrl[p.id]?.text ?? '') ?? 0;
                }
                Navigator.pop(ctx, {'boxes': boxes, 'pieces': pieces});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _returnBoxes.clear();
        _returnBoxes.addAll(result['boxes']!);
        _returnPieces.clear();
        _returnPieces.addAll(result['pieces']!);
        _calculateReturnValue();
      });
      await _saveReturnsToDB();
    }
  }

  void _calculateReturnValue() {
    double val = 0.0;
    for (var p in _products) {
      final boxes = _returnBoxes[p.id] ?? 0;
      final pieces = _returnPieces[p.id] ?? 0;
      val += (boxes * p.piecesPerBox + pieces) * _getPrice(p.id);
    }
    _totalReturnedValue = val;
  }

  Future<void> _saveReturnsToDB() async {
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    for (var entry in _oldReturnPieces.entries) {
      if (entry.value > 0) {
        final stockList = await db.query(DBConstants.tableStock,
            where: 'product_id = ?', whereArgs: [entry.key]);
        if (stockList.isNotEmpty) {
          final currentQty = stockList.first['quantity_pieces'] as int? ?? 0;
          await db.update(DBConstants.tableStock, {
            'quantity_pieces': currentQty - entry.value,
            'updated_at': now,
          }, where: 'product_id = ?', whereArgs: [entry.key]);
        }
      }
    }

    await db.delete(DBConstants.tableDistributorLoadReturns,
        where: 'load_id = ?', whereArgs: [widget.loadId]);

    final items = <Map<String, dynamic>>[];
    for (var p in _products) {
      final boxes = _returnBoxes[p.id] ?? 0;
      final pieces = _returnPieces[p.id] ?? 0;
      final totalPieces = boxes * p.piecesPerBox + pieces;
      if (totalPieces > 0) {
        items.add({
          'productId': p.id,
          'boxes': boxes,
          'pieces': pieces,
          'boxSize': p.piecesPerBox,
          'unitPrice': _getPrice(p.id),
        });
      }
      _oldReturnPieces[p.id] = totalPieces;
    }
    if (items.isNotEmpty) {
      await _returnRepo.recordReturn(
        distributorId: widget.distributor.id,
        loadId: widget.loadId,
        returnItems: items,
      );
    }
  }

  Future<void> _openDamageDialog() async {
    final prices = await _damageRepo.getDamagePrices(widget.distributor.id);
    final smallPrice = prices['صغير'] ?? 0;
    final largePrice = prices['كبير'] ?? 0;
    final tamerPrice = prices['تمرية كبير'] ?? 0;

    final smallCtrl = TextEditingController(text: _damageSmall.toString());
    final largeCtrl = TextEditingController(text: _damageLarge.toString());
    final tamerCtrl = TextEditingController(text: _damageTamer.toString());

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تالف الحملة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: smallCtrl,
              decoration: InputDecoration(labelText: 'صغير (سعر القطعة: $smallPrice)', isDense: true),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: largeCtrl,
              decoration: InputDecoration(labelText: 'كبير (سعر القطعة: $largePrice)', isDense: true),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: tamerCtrl,
              decoration: InputDecoration(labelText: 'تمرية كبير (سعر القطعة: $tamerPrice)', isDense: true),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'small': int.tryParse(smallCtrl.text) ?? 0,
                'large': int.tryParse(largeCtrl.text) ?? 0,
                'tamer': int.tryParse(tamerCtrl.text) ?? 0,
              });
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _damageSmall = result['small']!;
        _damageLarge = result['large']!;
        _damageTamer = result['tamer']!;
        _calculateDamageValue();
      });
      await _saveDamageToDB();
    }
  }

  void _calculateDamageValue() {
    _totalDamagedValue = (_damageSmall * (_damagePrices['صغير'] ?? 0)) +
        (_damageLarge * (_damagePrices['كبير'] ?? 0)) +
        (_damageTamer * (_damagePrices['تمرية كبير'] ?? 0));
  }

  Future<void> _saveDamageToDB() async {
    final db = await DatabaseHelper().database;
    await db.delete(DBConstants.tableDistributorLoadDamage,
        where: 'load_id = ?', whereArgs: [widget.loadId]);

    final items = <Map<String, dynamic>>[];
    if (_damageSmall > 0) items.add({'damageType': 'صغير', 'pieces': _damageSmall, 'pricePerPiece': _damagePrices['صغير'] ?? 0});
    if (_damageLarge > 0) items.add({'damageType': 'كبير', 'pieces': _damageLarge, 'pricePerPiece': _damagePrices['كبير'] ?? 0});
    if (_damageTamer > 0) items.add({'damageType': 'تمرية كبير', 'pieces': _damageTamer, 'pricePerPiece': _damagePrices['تمرية كبير'] ?? 0});

    if (items.isNotEmpty) {
      await _damageRepo.recordDamage(
        distributorId: widget.distributor.id,
        loadId: widget.loadId,
        damageItems: items,
      );
    }
  }

  Future<void> _settleLoad() async {
    final cash = double.tryParse(_cashCtrl.text) ?? 0;
    try {
      await _distRepo.settleDistributor(
        distributorId: widget.distributor.id,
        loadId: widget.loadId,
        collectedCash: cash,
        totalLoadValue: _totalLoadValue,
        totalReturnedValue: _totalReturnedValue,
        totalDamagedValue: _totalDamagedValue,
        commissionPercent: widget.distributor.commissionPercent,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت التصفية بنجاح'), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMsg('خطأ: $e', success: false);
    }
  }

  void _showMsg(String msg, {bool success = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ));
    }
  }

  @override
  void dispose() {
    for (var c in _boxesCtrl.values) { c.dispose(); }
    for (var c in _piecesCtrl.values) { c.dispose(); }
    _cashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previousBalance = widget.distributor.currentBalance;
    final commissionPercent = widget.distributor.commissionPercent;
    final netAfterExpenses = _totalLoadValue
        - (_totalLoadValue * (commissionPercent / 100))
        - _totalReturnedValue
        - _totalDamagedValue
        - (double.tryParse(_cashCtrl.text) ?? 0);
    final finalBalance = previousBalance + netAfterExpenses;

    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل حملة $_loadDate')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _infoTile('الموزع', widget.distributor.name, Icons.person),
                            _infoTile('التاريخ', _loadDate ?? '-', Icons.date_range),
                            _infoTile('الحالة', _loadStatus ?? '-', Icons.info),
                          ]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _infoTile('الرصيد السابق', previousBalance.toStringAsFixed(2), Icons.history, color: Colors.orange),
                            _infoTile('الرصيد النهائي المتوقع', finalBalance.toStringAsFixed(2), Icons.account_balance_wallet, color: finalBalance >= 0 ? Colors.green : Colors.red),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('🚚 التحميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ..._products.map((p) {
                    final boxes = int.tryParse(_boxesCtrl[p.id]?.text ?? '') ?? 0;
                    final pieces = int.tryParse(_piecesCtrl[p.id]?.text ?? '') ?? 0;
                    final total = boxes * p.piecesPerBox + pieces;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(p.name)),
                            Expanded(
                              child: TextField(
                                controller: _boxesCtrl[p.id],
                                decoration: const InputDecoration(labelText: 'سلال', isDense: true),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(_calculateTotals),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _piecesCtrl[p.id],
                                decoration: const InputDecoration(labelText: 'قطع', isDense: true),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(_calculateTotals),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('${total * _getPrice(p.id)} ر.ي'),
                          ],
                        ),
                      ),
                    );
                  }),
                  Text('إجمالي التحميل: $_totalLoadValue ر.ي', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _saveLoad,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ التحميل'),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('🔄 المرتجعات', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('الإجمالي: $_totalReturnedValue ر.ي'),
                          ]),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _openReturnsDialog,
                            icon: const Icon(Icons.edit),
                            label: const Text('إدخال المرتجعات'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('🗑️ التالف', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('الإجمالي: $_totalDamagedValue ر.ي'),
                          ]),
                          if (_damageSmall > 0) Text('صغير: $_damageSmall قطعة'),
                          if (_damageLarge > 0) Text('كبير: $_damageLarge قطعة'),
                          if (_damageTamer > 0) Text('تمرية كبير: $_damageTamer قطعة'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _openDamageDialog,
                            icon: const Icon(Icons.edit),
                            label: const Text('إدخال التالف'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    color: Colors.grey.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الحساب النهائي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Divider(),
                          _calcRow('الرصيد السابق', previousBalance),
                          _calcRow('قيمة الحملة', _totalLoadValue),
                          _calcRow('الخصم (${commissionPercent}%)', -_totalLoadValue * (commissionPercent / 100), color: Colors.red),
                          _calcRow('المرتجعات', -_totalReturnedValue, color: Colors.orange),
                          _calcRow('التالف', -_totalDamagedValue, color: Colors.red),
                          _calcRow('النقد المسلم', -(double.tryParse(_cashCtrl.text) ?? 0), color: Colors.green),
                          const Divider(),
                          _calcRow('الرصيد النهائي', finalBalance, bold: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('💰 النقد والتصفية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cashCtrl,
                            decoration: const InputDecoration(labelText: 'النقد المسلم', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _settleLoad,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('تسوية وإغلاق الحملة'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(45)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, {Color color = Colors.indigo}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _calcRow(String label, double amount, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('${amount >= 0 ? "+" : ""}${amount.toStringAsFixed(2)} ر.ي',
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
