import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../../data/models/distributor.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/distributor_repository.dart';

class DistributorAccountScreen extends StatefulWidget {
  final Distributor distributor;
  const DistributorAccountScreen({super.key, required this.distributor});

  @override
  State<DistributorAccountScreen> createState() => _DistributorAccountScreenState();
}

class _DistributorAccountScreenState extends State<DistributorAccountScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final DistributorRepository _distRepo = DistributorRepository();

  List<Product> _products = [];
  Map<String, double> _pricesForDistributor = {};
  double _prevBalance = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _previousLoads = [];

  // ----- بيانات الحملة المفتوحة حاليًا -----
  String? _currentLoadId;
  String? _currentLoadDate;
  String? _currentLoadStatus;

  // ----- حقول التحميل (السلال والقطع) -----
  Map<String, TextEditingController> _boxesControllers = {};
  Map<String, TextEditingController> _piecesControllers = {};

  // ----- حقول المرتجعات (لكل منتج) -----
  Map<String, TextEditingController> _returnedBoxesCtrl = {};
  Map<String, TextEditingController> _returnedPiecesCtrl = {};

  // ----- حقول التالف (لكل منتج) -----
  Map<String, TextEditingController> _damagedBoxesCtrl = {};
  Map<String, TextEditingController> _damagedPiecesCtrl = {};
  Map<String, TextEditingController> _damagedPriceCtrl = {};

  // ----- حقول النقد والخصم -----
  final TextEditingController _cashCtrl = TextEditingController();
  final TextEditingController _discountPercentCtrl = TextEditingController();

  // ----- الأرصدة -----
  double _collectedCash = 0;
  double _returnedValue = 0;
  double _damagedValue = 0;

  @override
  void initState() {
    super.initState();
    _discountPercentCtrl.text = '${widget.distributor.commissionPercent}';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      final products = await _productRepo.getAll();

      for (var p in products) {
        _pricesForDistributor[p.id] = p.wholesalePrice;
      }

      _prevBalance = widget.distributor.currentBalance;

      final prevLoads = await db.query(
        DBConstants.tableDistributorLoads,
        where: 'distributor_id = ?',
        whereArgs: [widget.distributor.id],
        orderBy: 'created_at DESC',
        limit: 20,
      );

      setState(() {
        _products = products.where((p) => p.active).toList();
        _previousLoads = prevLoads;
        _initControllers();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _initControllers() {
    for (var p in _products) {
      _boxesControllers[p.id] ??= TextEditingController();
      _piecesControllers[p.id] ??= TextEditingController();
      _returnedBoxesCtrl[p.id] ??= TextEditingController();
      _returnedPiecesCtrl[p.id] ??= TextEditingController();
      _damagedBoxesCtrl[p.id] ??= TextEditingController();
      _damagedPiecesCtrl[p.id] ??= TextEditingController();
      _damagedPriceCtrl[p.id] ??= TextEditingController();
    }
  }

  // ============ دوال المساعدة ============
  int _boxSize(String productId) {
    final p = _products.firstWhere((x) => x.id == productId);
    return p.piecesPerBox;
  }

  int _parsePieces(TextEditingController? boxesCtrl, TextEditingController? piecesCtrl, int boxSize) {
    final boxes = int.tryParse(boxesCtrl?.text ?? '') ?? 0;
    final pieces = int.tryParse(piecesCtrl?.text ?? '') ?? 0;
    return (boxes * boxSize) + pieces;
  }

  String _piecesToDisplay(int pieces, int boxSize) {
    if (boxSize <= 0) return '$pieces';
    final boxes = pieces ~/ boxSize;
    final remaining = pieces % boxSize;
    return '$boxes.$remaining';
  }

  // ============ فتح حملة سابقة ============
  Future<void> _openPreviousLoad(String loadId, String loadDate, String status) async {
    setState(() {
      _currentLoadId = loadId;
      _currentLoadDate = loadDate;
      _currentLoadStatus = status;
      for (var p in _products) {
        _boxesControllers[p.id]?.text = '';
        _piecesControllers[p.id]?.text = '';
        _returnedBoxesCtrl[p.id]?.text = '';
        _returnedPiecesCtrl[p.id]?.text = '';
        _damagedBoxesCtrl[p.id]?.text = '';
        _damagedPiecesCtrl[p.id]?.text = '';
        _damagedPriceCtrl[p.id]?.text = '';
      }
      _cashCtrl.text = '';
      _collectedCash = 0;
      _returnedValue = 0;
      _damagedValue = 0;
    });
  }

  // ============ إنشاء حملة جديدة ============
  Future<void> _createNewLoad() async {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    setState(() {
      _currentLoadId = null;
      _currentLoadDate = now;
      _currentLoadStatus = 'مفتوحة';
      for (var p in _products) {
        _boxesControllers[p.id]?.text = '';
        _piecesControllers[p.id]?.text = '';
        _returnedBoxesCtrl[p.id]?.text = '';
        _returnedPiecesCtrl[p.id]?.text = '';
        _damagedBoxesCtrl[p.id]?.text = '';
        _damagedPiecesCtrl[p.id]?.text = '';
        _damagedPriceCtrl[p.id]?.text = '';
      }
      _cashCtrl.text = '';
      _collectedCash = 0;
      _returnedValue = 0;
      _damagedValue = 0;
    });
  }

  // ============ حفظ التحميل ============
  Future<void> _saveLoad() async {
    final items = <Map<String, dynamic>>[];
    for (var p in _products) {
      final qty = _parsePieces(_boxesControllers[p.id], _piecesControllers[p.id], _boxSize(p.id));
      if (qty > 0) {
        items.add({'productId': p.id, 'quantity': qty});
      }
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف كميات للتحميل')));
      return;
    }

    try {
      final loadId = await _distRepo.createLoad(
        distributorId: widget.distributor.id,
        items: items,
      );
      setState(() {
        _currentLoadId = loadId;
        _currentLoadDate = DateTime.now().toIso8601String().substring(0, 10);
        _currentLoadStatus = 'مفتوحة';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التحميل'), backgroundColor: AppTheme.successColor));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  // ============ حفظ المرتجعات ============
  Future<void> _saveReturns() async {
    if (_currentLoadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد حملة مفتوحة')));
      return;
    }
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    try {
      await db.transaction((txn) async {
        for (var p in _products) {
          final returned = _parsePieces(_returnedBoxesCtrl[p.id], _returnedPiecesCtrl[p.id], _boxSize(p.id));
          if (returned <= 0) continue;

          final existing = await txn.query(
            DBConstants.tableDistributorReturns,
            where: 'load_id = ? AND product_id = ?',
            whereArgs: [_currentLoadId, p.id],
          );

          int oldReturned = 0;
          if (existing.isNotEmpty) {
            oldReturned = existing.first['returned'] as int? ?? 0;
            await txn.update(
              DBConstants.tableDistributorReturns,
              {
                'returned': returned,
                'settlement_date': DateTime.now().toIso8601String().substring(0, 10),
                'created_at': now,
              },
              where: 'load_id = ? AND product_id = ?',
              whereArgs: [_currentLoadId, p.id],
            );
          } else {
            await txn.insert(DBConstants.tableDistributorReturns, {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'distributor_id': widget.distributor.id,
              'load_id': _currentLoadId,
              'product_id': p.id,
              'sold': 0,
              'returned': returned,
              'damaged': 0,
              'collected_cash': 0,
              'commission': 0,
              'net_amount': 0,
              'settlement_date': DateTime.now().toIso8601String().substring(0, 10),
              'created_at': now,
              'created_by': 'admin',
              'device_id': 'mobile',
              'sync_status': 'Pending',
            });
          }

          final diff = returned - oldReturned;
          if (diff != 0) {
            final stock = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [p.id]);
            if (stock.isNotEmpty) {
              final currentQty = stock.first['quantity_pieces'] as int? ?? 0;
              await txn.update(
                DBConstants.tableStock,
                {'quantity_pieces': currentQty + diff, 'updated_at': now},
                where: 'product_id = ?',
                whereArgs: [p.id],
              );
            }
            await txn.insert(DBConstants.tableStockMovements, {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'product_id': p.id,
              'movement_type': 'مرتجع موزع',
              'quantity': diff,
              'reference_id': _currentLoadId,
              'reference_type': 'distributor_return',
              'notes': 'مرتجع موزع - حملة $_currentLoadId',
              'created_at': now,
              'sync_status': 'Pending',
            });
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المرتجعات'), backgroundColor: AppTheme.successColor));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  // ============ حفظ التالف ============
  Future<void> _saveDamaged() async {
    if (_currentLoadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد حملة مفتوحة')));
      return;
    }
    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    try {
      await db.transaction((txn) async {
        for (var p in _products) {
          final damagedQty = _parsePieces(_damagedBoxesCtrl[p.id], _damagedPiecesCtrl[p.id], _boxSize(p.id));
          final price = double.tryParse(_damagedPriceCtrl[p.id]?.text ?? '') ?? 0;
          if (damagedQty <= 0 && price <= 0) continue;

          final existing = await txn.query(
            DBConstants.tableDistributorReturns,
            where: 'load_id = ? AND product_id = ?',
            whereArgs: [_currentLoadId, p.id],
          );

          if (existing.isNotEmpty) {
            await txn.update(
              DBConstants.tableDistributorReturns,
              {
                'damaged': damagedQty,
                'commission': price * damagedQty,
                'created_at': now,
              },
              where: 'load_id = ? AND product_id = ?',
              whereArgs: [_currentLoadId, p.id],
            );
          } else {
            await txn.insert(DBConstants.tableDistributorReturns, {
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'distributor_id': widget.distributor.id,
              'load_id': _currentLoadId,
              'product_id': p.id,
              'sold': 0,
              'returned': 0,
              'damaged': damagedQty,
              'collected_cash': 0,
              'commission': price * damagedQty,
              'net_amount': 0,
              'settlement_date': DateTime.now().toIso8601String().substring(0, 10),
              'created_at': now,
              'created_by': 'admin',
              'device_id': 'mobile',
              'sync_status': 'Pending',
            });
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التالف'), backgroundColor: AppTheme.successColor));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  // ============ تصفية وإغلاق الحملة ============
  Future<void> _settleLoad() async {
    if (_currentLoadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد حملة مفتوحة')));
      return;
    }
    final cash = double.tryParse(_cashCtrl.text) ?? 0;
    try {
      await _distRepo.settleDistributor(
        distributorId: widget.distributor.id,
        loadId: _currentLoadId!,
        items: [],
        collectedCash: cash,
      );
      setState(() {
        _currentLoadStatus = 'مغلقة';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت التصفية'), backgroundColor: AppTheme.successColor));
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.errorColor));
      }
    }
  }

  // ============ تفاصيل حملة سابقة ============
  Future<void> _showLoadDetails(String loadId) async {
    final db = await DatabaseHelper().database;
    final returns = await db.query(DBConstants.tableDistributorReturns, where: 'load_id = ?', whereArgs: [loadId]);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل الحملة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...returns.map((r) => ListTile(
                title: Text('المنتج: ${r['product_id']}'),
                subtitle: Text('مرتجع: ${r['returned']} | تالف: ${r['damaged']} | قيمة التالف: ${r['commission']}'),
              )),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  // ============ واجهة المستخدم ============
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
                  // رأس الكشف
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _infoCard('الموزع', widget.distributor.name, Icons.person),
                            _infoCard('السيارة', widget.distributor.vehicle ?? '-', Icons.local_shipping),
                            _infoCard('نسبة الخصم', '%${widget.distributor.commissionPercent}', Icons.discount),
                          ]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _infoCard('الرصيد المرحل', '${_prevBalance.toStringAsFixed(0)} ر.ي', Icons.arrow_forward, color: AppTheme.warningColor),
                            _infoCard('الرصيد الحالي', '${widget.distributor.currentBalance.toStringAsFixed(0)} ر.ي', Icons.account_balance_wallet, color: AppTheme.errorColor),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // أزرار التحكم بالحملة
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    ElevatedButton.icon(onPressed: _createNewLoad, icon: const Icon(Icons.add), label: const Text('حملة جديدة')),
                    ElevatedButton.icon(onPressed: _saveLoad, icon: const Icon(Icons.save), label: const Text('حفظ التحميل')),
                  ]),
                  if (_currentLoadId != null) ...[
                    const SizedBox(height: 8),
                    Text('الحملة الحالية: $_currentLoadId (${_currentLoadStatus ?? ''})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 16),

                  // ========== التحميل ==========
                  const Text('🚚 التحميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ...(_products.map((p) {
                    final total = _parsePieces(_boxesControllers[p.id], _piecesControllers[p.id], _boxSize(p.id));
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('السلة: ${p.piecesPerBox} | السعر: ${_pricesForDistributor[p.id]?.toStringAsFixed(0)} ر.ي'),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _boxesControllers[p.id], decoration: const InputDecoration(labelText: 'سلال', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                                Expanded(child: TextField(controller: _piecesControllers[p.id], decoration: InputDecoration(labelText: 'قطع', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                              ],
                            ),
                            Text('الكمية: ${_piecesToDisplay(total, _boxSize(p.id))} ($total قطعة)'),
                            Text('القيمة: ${(total * (_pricesForDistributor[p.id] ?? 0)).toStringAsFixed(0)} ر.ي'),
                          ],
                        ),
                      ),
                    );
                  })),
                  const SizedBox(height: 16),

                  // ========== المرتجعات ==========
                  const Text('🔄 المرتجعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ...(_products.map((p) {
                    final returned = _parsePieces(_returnedBoxesCtrl[p.id], _returnedPiecesCtrl[p.id], _boxSize(p.id));
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _returnedBoxesCtrl[p.id], decoration: const InputDecoration(labelText: 'سلال', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                                Expanded(child: TextField(controller: _returnedPiecesCtrl[p.id], decoration: InputDecoration(labelText: 'قطع', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                              ],
                            ),
                            Text('مرتجع: ${_piecesToDisplay(returned, _boxSize(p.id))} ($returned قطعة)'),
                            Text('القيمة: ${(returned * (_pricesForDistributor[p.id] ?? 0)).toStringAsFixed(0)} ر.ي'),
                          ],
                        ),
                      ),
                    );
                  })),
                  ElevatedButton.icon(onPressed: _saveReturns, icon: const Icon(Icons.save), label: const Text('حفظ المرتجعات')),
                  const SizedBox(height: 16),

                  // ========== التالف ==========
                  const Text('🗑️ التالف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ...(_products.map((p) {
                    final damaged = _parsePieces(_damagedBoxesCtrl[p.id], _damagedPiecesCtrl[p.id], _boxSize(p.id));
                    final price = double.tryParse(_damagedPriceCtrl[p.id]?.text ?? '') ?? 0;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _damagedBoxesCtrl[p.id], decoration: const InputDecoration(labelText: 'سلال', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                                Expanded(child: TextField(controller: _damagedPiecesCtrl[p.id], decoration: InputDecoration(labelText: 'قطع', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                              ],
                            ),
                            TextField(controller: _damagedPriceCtrl[p.id], decoration: const InputDecoration(labelText: 'سعر الوحدة', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                            Text('تالف: ${_piecesToDisplay(damaged, _boxSize(p.id))} ($damaged قطعة) | القيمة: ${(damaged * price).toStringAsFixed(0)} ر.ي'),
                          ],
                        ),
                      ),
                    );
                  })),
                  ElevatedButton.icon(onPressed: _saveDamaged, icon: const Icon(Icons.save), label: const Text('حفظ التالف')),
                  const SizedBox(height: 16),

                  // ========== النقد والتصفية ==========
                  const Text('💰 النقد والتصفية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextField(controller: _cashCtrl, decoration: const InputDecoration(labelText: 'النقد الموصل', hintText: '0'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: _settleLoad, icon: const Icon(Icons.check_circle), label: const Text('تصفية وإغلاق الحملة'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor)),

                  // ========== الحملات السابقة ==========
                  const SizedBox(height: 24),
                  const Text('📦 الحملات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
}
