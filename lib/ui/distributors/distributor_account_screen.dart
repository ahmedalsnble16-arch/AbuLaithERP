import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/distributor.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_repository.dart';
import '../../data/repositories/distributor_return_repository.dart';
import '../../data/repositories/distributor_damage_repository.dart';

class DistributorAccountScreen extends StatefulWidget {
  final Distributor distributor;
  const DistributorAccountScreen({super.key, required this.distributor});

  @override
  State<DistributorAccountScreen> createState() => _DistributorAccountScreenState();
}

class _DistributorAccountScreenState extends State<DistributorAccountScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DistributorRepository _distRepo = DistributorRepository();
  final DistributorReturnRepository _returnRepo = DistributorReturnRepository();
  final DistributorDamageRepository _damageRepo = DistributorDamageRepository();

  List<Product> _products = [];
  Map<String, TextEditingController> _boxesControllers = {};
  Map<String, TextEditingController> _piecesControllers = {};
  Map<String, double> _pricesForDistributor = {};
  Map<String, double> _damagePrices = {};

  double _prevBalance = 0;
  double _collectedCash = 0;
  double _returnedValue = 0;
  double _damagedValue = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _previousLoads = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      // 1. المنتجات النشطة
      final products = await _productRepo.getAll();

      // 2. الأسعار الخاصة بالموزع (من جدول distributor_product_prices)
      for (var p in products) {
        _pricesForDistributor[p.id] = p.wholesalePrice;
      }

      // 3. أسعار التالف
      _damagePrices = await _damageRepo.getDamagePrices(widget.distributor.id);
      // تعيين قيم افتراضية إذا كانت فارغة
      if (!_damagePrices.containsKey('صغير')) _damagePrices['صغير'] = 0;
      if (!_damagePrices.containsKey('كبير')) _damagePrices['كبير'] = 0;
      if (!_damagePrices.containsKey('تمرية_كبير')) _damagePrices['تمرية_كبير'] = 0;

      // 4. الرصيد المرحل
      _prevBalance = widget.distributor.currentBalance;

      // 5. الحملات السابقة
      final prevLoads = await db.query(
        DBConstants.tableDistributorLoads,
        where: 'distributor_id = ?',
        whereArgs: [widget.distributor.id],
        orderBy: 'created_at DESC',
        limit: 5,
      );

      setState(() {
        _products = products.where((p) => p.active).toList();
        for (var p in _products) {
          _boxesControllers[p.id] = TextEditingController(text: '0');
          _piecesControllers[p.id] = TextEditingController(text: '0');
        }
        _previousLoads = prevLoads;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int _totalPieces(String productId) {
    final product = _products.firstWhere((p) => p.id == productId);
    final boxes = int.tryParse(_boxesControllers[productId]?.text ?? '0') ?? 0;
    final pieces = int.tryParse(_piecesControllers[productId]?.text ?? '0') ?? 0;
    return (boxes * product.piecesPerBox) + pieces;
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.${remaining.toString().padLeft(2, '0')}';
  }

  double _loadValue(String productId) {
    final price = _pricesForDistributor[productId] ?? 0;
    return _totalPieces(productId) * price;
  }

  double get _totalLoadValue => _products.fold(0, (sum, p) => sum + _loadValue(p.id));
  double get _discountValue => _totalLoadValue * (widget.distributor.commissionPercent / 100);
  double get _totalRequired => _prevBalance + _totalLoadValue;
  double get _finalBalance => _totalRequired - _discountValue - _collectedCash - _returnedValue - _damagedValue;

  // ============ نافذة المرتجعات ============
  Future<void> _showReturnsDialog() async {
    final boxesCtrl = <String, TextEditingController>{};
    final piecesCtrl = <String, TextEditingController>{};
    for (var p in _products) {
      boxesCtrl[p.id] = TextEditingController(text: '0');
      piecesCtrl[p.id] = TextEditingController(text: '0');
    }

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مرتجعات الموزع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _products.map((p) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('السلة: ${p.piecesPerBox} قطعة | السعر: ${_pricesForDistributor[p.id] ?? p.wholesalePrice}'),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: boxesCtrl[p.id], decoration: const InputDecoration(labelText: 'سلال'), keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: piecesCtrl[p.id], decoration: InputDecoration(labelText: 'قطع (< ${p.piecesPerBox})'), keyboardType: TextInputType.number)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final items = <Map<String, dynamic>>[];
              double totalValue = 0;
              for (var p in _products) {
                final boxes = int.tryParse(boxesCtrl[p.id]?.text ?? '0') ?? 0;
                final pieces = int.tryParse(piecesCtrl[p.id]?.text ?? '0') ?? 0;
                final total = (boxes * p.piecesPerBox) + pieces;
                if (total > 0) {
                  final unitPrice = _pricesForDistributor[p.id] ?? p.wholesalePrice;
                  totalValue += total * unitPrice;
                  items.add({
                    'productId': p.id,
                    'boxes': boxes,
                    'pieces': pieces,
                    'boxSize': p.piecesPerBox,
                    'totalPieces': total,
                    'unitPrice': unitPrice,
                  });
                }
              }
              Navigator.pop(ctx, items);
            },
            child: const Text('حفظ المرتجعات'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final db = await DatabaseHelper().database;
        double totalValue = 0;
        await db.transaction((txn) async {
          await _returnRepo.recordReturn(
            distributorId: widget.distributor.id,
            loadId: null,
            returnItems: result,
            txn: txn,
          );
          totalValue = await _returnRepo.getTotalReturnValue(distributorId: widget.distributor.id, txn: txn);
        });
        setState(() {
          _returnedValue = totalValue;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل المرتجعات وإرجاعها للمخزن'), backgroundColor: AppTheme.successColor),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ============ نافذة التالف ============
  Future<void> _showDamageDialog() async {
    final types = ['صغير', 'كبير', 'تمرية_كبير'];
    final names = {'صغير': 'صغير', 'كبير': 'كبير', 'تمرية_كبير': 'تمرية كبير'};
    final piecesCtrl = <String, TextEditingController>{};
    for (var t in types) {
      piecesCtrl[t] = TextEditingController(text: '0');
    }

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تالف الموزع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: types.map((type) {
              final price = _damagePrices[type] ?? 0;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(names[type] ?? type, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('سعر القطعة: $price'),
                      TextField(
                        controller: piecesCtrl[type],
                        decoration: const InputDecoration(labelText: 'عدد القطع'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final items = <Map<String, dynamic>>[];
              for (var t in types) {
                final pieces = int.tryParse(piecesCtrl[t]?.text ?? '0') ?? 0;
                if (pieces > 0) {
                  items.add({
                    'damageType': t,
                    'pieces': pieces,
                    'pricePerPiece': _damagePrices[t] ?? 0,
                  });
                }
              }
              Navigator.pop(ctx, items);
            },
            child: const Text('حفظ التالف'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final db = await DatabaseHelper().database;
        double totalValue = 0;
        await db.transaction((txn) async {
          await _damageRepo.recordDamage(
            distributorId: widget.distributor.id,
            loadId: null,
            damageItems: result,
            txn: txn,
          );
          totalValue = await _damageRepo.getTotalDamageValue(distributorId: widget.distributor.id, txn: txn);
        });
        setState(() {
          _damagedValue = totalValue;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل التالف'), backgroundColor: AppTheme.successColor),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // ============ تفاصيل حملة سابقة ============
  Future<void> _showLoadDetails(String loadId) async {
    final db = await DatabaseHelper().database;
    final loadData = await db.query(DBConstants.tableDistributorLoads, where: 'id = ?', whereArgs: [loadId]);
    if (loadData.isEmpty) return;

    final returns = await db.query(DBConstants.tableDistributorLoadReturns, where: 'load_id = ?', whereArgs: [loadId]);
    final damages = await db.query(DBConstants.tableDistributorLoadDamage, where: 'load_id = ?', whereArgs: [loadId]);
    final items = await db.query(DBConstants.tableDistributorLoadItems, where: 'load_id = ?', whereArgs: [loadId]);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفاصيل الحملة: ${loadData.first['load_date']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التاريخ: ${loadData.first['load_date']}'),
              Text('الحالة: ${loadData.first['status']}'),
              const Divider(),
              const Text('📦 المنتجات المحملة:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...items.map((item) => ListTile(
                title: Text('المنتج: ${item['product_id']}'),
                subtitle: Text('الكمية: ${item['quantity']} | السعر: ${item['unit_price']}'),
              )),
              const Divider(),
              const Text('🔄 المرتجعات:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...returns.map((r) => ListTile(
                title: Text('المنتج: ${r['product_id']}'),
                subtitle: Text('سلال: ${r['boxes']} | قطع: ${r['pieces']} | إجمالي: ${r['total_pieces']} قطعة | قيمة: ${r['total_value']}'),
              )),
              const Divider(),
              const Text('🗑️ التالف:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...damages.map((d) => ListTile(
                title: Text('النوع: ${d['damage_type']}'),
                subtitle: Text('عدد القطع: ${d['pieces']} | سعر القطعة: ${d['price_per_piece']} | قيمة: ${d['total_value']}'),
              )),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<void> _saveLoad() async {
    final items = _products
        .where((p) => _totalPieces(p.id) > 0)
        .map((p) => {
              'productId': p.id,
              'quantity': _totalPieces(p.id),
              'unitPrice': _pricesForDistributor[p.id] ?? p.wholesalePrice,
            })
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف كميات للحملة')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _distRepo.createLoad(
        distributorId: widget.distributor.id,
        items: items,
      );

      final db = await DatabaseHelper().database;
      await db.update(
        DBConstants.tableDistributors,
        {'current_balance': _finalBalance, 'updated_at': DatabaseHelper.now},
        where: 'id = ?',
        whereArgs: [widget.distributor.id],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الحملة بنجاح'), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var c in _boxesControllers.values) { c.dispose(); }
    for (var c in _piecesControllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب: ${widget.distributor.name}')),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoCard('الموزع', widget.distributor.name, Icons.person),
                              _infoCard('السيارة', widget.distributor.vehicle ?? '-', Icons.local_shipping),
                              _infoCard('نسبة الخصم', '%${widget.distributor.commissionPercent}', Icons.discount),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoCard('الرصيد المرحل', '${_prevBalance.toStringAsFixed(0)} ر.ي', Icons.arrow_forward, color: AppTheme.warningColor),
                              _infoCard('الرصيد الحالي', '${widget.distributor.currentBalance.toStringAsFixed(0)} ر.ي', Icons.account_balance_wallet, color: AppTheme.errorColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('🚚 الحملة الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(_products.map((p) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('السلة: ${p.piecesPerBox} قطعة', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                              ],
                            ),
                            Text('سعر الموزع: ${_pricesForDistributor[p.id]?.toStringAsFixed(0) ?? '0'} ر.ي'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _boxesControllers[p.id],
                                    decoration: const InputDecoration(labelText: 'عدد السلال'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _piecesControllers[p.id],
                                    decoration: InputDecoration(labelText: 'قطع (< ${p.piecesPerBox})'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الكمية: ${_piecesToDisplay(_totalPieces(p.id), p.piecesPerBox)} (${_totalPieces(p.id)} قطعة)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'قيمة التحميل: ${_loadValue(p.id).toStringAsFixed(0)} ر.ي',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  })),
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.primaryColor.withAlpha(15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _calcRow('إجمالي قيمة الحملة', '${_totalLoadValue.toStringAsFixed(0)} ر.ي'),
                          _calcRow('الرصيد السابق', '${_prevBalance.toStringAsFixed(0)} ر.ي'),
                          _calcRow('المطلوب', '${_totalRequired.toStringAsFixed(0)} ر.ي'),
                          _calcRow('قيمة الخصم (${widget.distributor.commissionPercent}%)', '- ${_discountValue.toStringAsFixed(0)} ر.ي'),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(labelText: 'النقد الموصل', prefixIcon: Icon(Icons.money)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() => _collectedCash = double.tryParse(v) ?? 0),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'قيمة المرجوع', prefixIcon: Icon(Icons.undo)),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: _returnedValue.toStringAsFixed(0)),
                                  enabled: false,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                                tooltip: 'تسجيل مرتجعات',
                                onPressed: _showReturnsDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'قيمة التالف', prefixIcon: Icon(Icons.delete)),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: _damagedValue.toStringAsFixed(0)),
                                  enabled: false,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                                tooltip: 'تسجيل تالف',
                                onPressed: _showDamageDialog,
                              ),
                            ],
                          ),
                          const Divider(),
                          _calcRow('💰 الرصيد النهائي (يرحل للحملة التالية)', '${_finalBalance.toStringAsFixed(0)} ر.ي', isBold: true, color: AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _saveLoad, icon: const Icon(Icons.save), label: const Text('حفظ الحملة')),
                  const SizedBox(height: 24),
                  const Text('📦 الحملات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(_previousLoads.map((load) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.receipt, color: Colors.white)),
                      title: Text('حملة ${load['load_date'] ?? ''}'),
                      subtitle: Text('الحالة: ${load['status'] ?? 'مغلقة'}'),
                      onTap: () => _showLoadDetails(load['id'] as String),
                    ),
                  ))),
                ],
              ),
            ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon, {Color color = AppTheme.primaryColor}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14, color: color)),
        ],
      ),
    );
  }
}
