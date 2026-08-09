import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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

  // ----- بيانات الحملة الحالية -----
  String? _currentLoadId;
  String? _currentLoadDate;
  String? _currentLoadStatus;

  // ----- المتحكمات (Controllers) -----
  final Map<String, TextEditingController> _boxesControllers = {};
  final Map<String, TextEditingController> _piecesControllers = {};

  final Map<String, TextEditingController> _returnedBoxesCtrl = {};
  final Map<String, TextEditingController> _returnedPiecesCtrl = {};

  final Map<String, TextEditingController> _damagedBoxesCtrl = {};
  final Map<String, TextEditingController> _damagedPiecesCtrl = {};
  final Map<String, TextEditingController> _damagedPriceCtrl = {};

  final TextEditingController _cashCtrl = TextEditingController();

  // ----- الأرصدة للحملة الحالية فقط -----
  double _loadTotalValue = 0;
  double _returnedTotalValue = 0;
  double _damagedTotalValue = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;
      final products = await _productRepo.getAll();

      for (var p in products) {
        _pricesForDistributor[p.id] = p.wholesalePrice;
      }

      _prevBalance = widget.distributor.currentBalance;

      // جلب الحملات السابقة
      final prevLoads = await db.query(
        DBConstants.tableDistributorLoads,
        where: 'distributor_id = ?',
        whereArgs: [widget.distributor.id],
        orderBy: 'created_at DESC',
      );

      _products = products.where((p) => p.active).toList();
      _previousLoads = prevLoads;
      _initControllers();

      // فتح أحدث حملة إن وجدت أو تجهيز حملة جديدة
      if (prevLoads.isNotEmpty) {
        await _loadLoadDetails(prevLoads.first['id'] as String);
      } else {
        _createNewLoad();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _initControllers() {
    for (var p in _products) {
      _boxesControllers[p.id] = TextEditingController();
      _piecesControllers[p.id] = TextEditingController();
      _returnedBoxesCtrl[p.id] = TextEditingController();
      _returnedPiecesCtrl[p.id] = TextEditingController();
      _damagedBoxesCtrl[p.id] = TextEditingController();
      _damagedPiecesCtrl[p.id] = TextEditingController();
      _damagedPriceCtrl[p.id] = TextEditingController();
    }
  }

  void _clearAllFields() {
    for (var p in _products) {
      _boxesControllers[p.id]?.clear();
      _piecesControllers[p.id]?.clear();
      _returnedBoxesCtrl[p.id]?.clear();
      _returnedPiecesCtrl[p.id]?.clear();
      _damagedBoxesCtrl[p.id]?.clear();
      _damagedPiecesCtrl[p.id]?.clear();
      _damagedPriceCtrl[p.id]?.clear();
    }
    _cashCtrl.clear();
    _loadTotalValue = 0;
    _returnedTotalValue = 0;
    _damagedTotalValue = 0;
  }

  int _boxSize(String productId) {
    return _products.firstWhere((x) => x.id == productId).piecesPerBox;
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

  // ============ تحميل تفاصيل حملة كاملة من الأرشيف ============
  Future<void> _loadLoadDetails(String loadId) async {
    final db = await DatabaseHelper().database;
    _clearAllFields();

    final loadData = await db.query(
      DBConstants.tableDistributorLoads,
      where: 'id = ?',
      whereArgs: [loadId],
    );

    if (loadData.isEmpty) return;

    final load = loadData.first;
    _currentLoadId = loadId;
    _currentLoadDate = load['load_date'] as String?;
    _currentLoadStatus = load['status'] as String?;

    // 1. تحميل مفردات التحميل
    final loadItems = await db.query(
      DBConstants.tableDistributorLoadItems,
      where: 'load_id = ?',
      whereArgs: [loadId],
    );

    for (var item in loadItems) {
      final pid = item['product_id'] as String;
      final totalQty = item['quantity'] as int;
      final bSize = _boxSize(pid);
      if (_boxesControllers.containsKey(pid)) {
        _boxesControllers[pid]!.text = (totalQty ~/ bSize).toString();
        _piecesControllers[pid]!.text = (totalQty % bSize).toString();
      }
    }

    // 2. تحميل المرتجعات للحملة الحالية فقط
    final returns = await db.query(
      DBConstants.tableDistributorLoadReturns,
      where: 'load_id = ?',
      whereArgs: [loadId],
    );

    for (var item in returns) {
      final pid = item['product_id'] as String;
      final boxes = item['boxes'] as int? ?? 0;
      final pieces = item['pieces'] as int? ?? 0;
      if (_returnedBoxesCtrl.containsKey(pid)) {
        _returnedBoxesCtrl[pid]!.text = boxes.toString();
        _returnedPiecesCtrl[pid]!.text = pieces.toString();
      }
    }

    // 3. تحميل التالف للحملة الحالية فقط
    final damages = await db.query(
      DBConstants.tableDistributorLoadDamage,
      where: 'load_id = ?',
      whereArgs: [loadId],
    );

    for (var item in damages) {
      final pid = item['product_id'] as String? ?? '';
      final pieces = item['pieces'] as int? ?? 0;
      final price = (item['price_per_piece'] as num? ?? 0).toDouble();
      final bSize = _boxSize(pid);

      if (_damagedBoxesCtrl.containsKey(pid)) {
        _damagedBoxesCtrl[pid]!.text = (pieces ~/ bSize).toString();
        _damagedPiecesCtrl[pid]!.text = (pieces % bSize).toString();
        _damagedPriceCtrl[pid]!.text = price.toStringAsFixed(0);
      }
    }

    _calculateTotals();
    setState(() {});
  }

  void _calculateTotals() {
    double loadVal = 0;
    double retVal = 0;
    double damVal = 0;

    for (var p in _products) {
      final price = _pricesForDistributor[p.id] ?? 0;
      final bSize = p.piecesPerBox;

      final loadQty = _parsePieces(_boxesControllers[p.id], _piecesControllers[p.id], bSize);
      loadVal += loadQty * price;

      final retQty = _parsePieces(_returnedBoxesCtrl[p.id], _returnedPiecesCtrl[p.id], bSize);
      retVal += retQty * price;

      final damQty = _parsePieces(_damagedBoxesCtrl[p.id], _damagedPiecesCtrl[p.id], bSize);
      final damPrice = double.tryParse(_damagedPriceCtrl[p.id]?.text ?? '') ?? 0;
      damVal += damQty * damPrice;
    }

    _loadTotalValue = loadVal;
    _returnedTotalValue = retVal;
    _damagedTotalValue = damVal;
  }

  // ============ إنشاء حملة جديدة ============
  void _createNewLoad() {
    _clearAllFields();
    setState(() {
      _currentLoadId = null;
      _currentLoadDate = DateTime.now().toIso8601String().substring(0, 10);
      _currentLoadStatus = 'مفتوحة';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كميات للتحميل أولاً')));
      return;
    }

    try {
      final loadId = await _distRepo.createLoad(
        distributorId: widget.distributor.id,
        items: items,
      );
      await _loadInitialData();
      await _loadLoadDetails(loadId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التحميل بنجاح'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ============ ثانياً: حفظ وتعديل المرتجعات وترحيل الفرق لمخزن الإنتاج ============
  Future<void> _saveReturns() async {
    if (_currentLoadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إنشاء وحفظ التحميل أولاً')));
      return;
    }

    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    try {
      await db.transaction((txn) async {
        for (var p in _products) {
          final boxes = int.tryParse(_returnedBoxesCtrl[p.id]?.text ?? '') ?? 0;
          final pieces = int.tryParse(_returnedPiecesCtrl[p.id]?.text ?? '') ?? 0;
          final totalPieces = _parsePieces(_returnedBoxesCtrl[p.id], _returnedPiecesCtrl[p.id], _boxSize(p.id));
          final unitPrice = _pricesForDistributor[p.id] ?? 0;
          final totalValue = totalPieces * unitPrice;

          // 1. البحث عن سجّل مرتجع سابق مرتبط بهذه الحملة والمنتج حصراً
          final existing = await txn.query(
            DBConstants.tableDistributorLoadReturns,
            where: 'load_id = ? AND product_id = ?',
            whereArgs: [_currentLoadId, p.id],
          );

          int oldReturnedPieces = 0;

          if (existing.isNotEmpty) {
            oldReturnedPieces = existing.first['total_pieces'] as int? ?? 0;

            if (totalPieces > 0) {
              await txn.update(
                DBConstants.tableDistributorLoadReturns,
                {
                  'boxes': boxes,
                  'pieces': pieces,
                  'total_pieces': totalPieces,
                  'unit_price': unitPrice,
                  'total_value': totalValue,
                  'return_date': _currentLoadDate,
                  'created_at': now,
                },
                where: 'id = ?',
                whereArgs: [existing.first['id']],
              );
            } else {
              await txn.delete(
                DBConstants.tableDistributorLoadReturns,
                where: 'id = ?',
                whereArgs: [existing.first['id']],
              );
            }
          } else if (totalPieces > 0) {
            await txn.insert(DBConstants.tableDistributorLoadReturns, {
              'id': const Uuid().v4(),
              'distributor_id': widget.distributor.id,
              'load_id': _currentLoadId,
              'product_id': p.id,
              'boxes': boxes,
              'pieces': pieces,
              'total_pieces': totalPieces,
              'unit_price': unitPrice,
              'total_value': totalValue,
              'return_date': _currentLoadDate,
              'created_at': now,
              'created_by': 'admin',
              'device_id': 'mobile',
              'sync_status': 'Pending',
            });
          }

          // 2. تصحيح المخزون بالفرق فقط (diff)
          final diff = totalPieces - oldReturnedPieces;
          if (diff != 0) {
            final stockRes = await txn.query(DBConstants.tableStock, where: 'product_id = ?', whereArgs: [p.id]);

            if (stockRes.isNotEmpty) {
              final currentStock = stockRes.first['quantity_pieces'] as int? ?? 0;
              await txn.update(
                DBConstants.tableStock,
                {
                  'quantity_pieces': currentStock + diff,
                  'updated_at': now,
                },
                where: 'product_id = ?',
                whereArgs: [p.id],
              );
            } else {
              await txn.insert(DBConstants.tableStock, {
                'id': const Uuid().v4(),
                'product_id': p.id,
                'quantity_pieces': diff,
                'reserved_quantity': 0,
                'average_cost': p.productionCost,
                'last_update': now,
                'created_at': now,
                'updated_at': now,
              });
            }

            // تسجل حركة مخزون بالفرق
            await txn.insert(DBConstants.tableStockMovements, {
              'id': const Uuid().v4(),
              'product_id': p.id,
              'movement_type': 'مرتجع موزع',
              'quantity': diff,
              'reference_id': _currentLoadId,
              'reference_type': 'distributor_return',
              'notes': 'تعديل مرتجع الموزع: ${widget.distributor.name} (حملة $_currentLoadId)',
              'created_at': now,
              'sync_status': 'Pending',
            });
          }
        }
      });

      _calculateTotals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المرتجعات وتحديث مخزن الإنتاج بنجاح'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ المرتجعات: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ============ رابعاً: حفظ التالف مع السعر وتحديد القيمة للحملة فقط ============
  Future<void> _saveDamaged() async {
    if (_currentLoadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إنشاء وحفظ التحميل أولاً')));
      return;
    }

    final db = await DatabaseHelper().database;
    final now = DatabaseHelper.now;

    try {
      await db.transaction((txn) async {
        for (var p in _products) {
          final damagedPieces = _parsePieces(_damagedBoxesCtrl[p.id], _damagedPiecesCtrl[p.id], _boxSize(p.id));
          final pricePerPiece = double.tryParse(_damagedPriceCtrl[p.id]?.text ?? '') ?? 0;
          final totalValue = damagedPieces * pricePerPiece;

          final existing = await txn.query(
            DBConstants.tableDistributorLoadDamage,
            where: 'load_id = ? AND product_id = ?',
            whereArgs: [_currentLoadId, p.id],
          );

          if (existing.isNotEmpty) {
            if (damagedPieces > 0) {
              await txn.update(
                DBConstants.tableDistributorLoadDamage,
                {
                  'damage_type': 'تالف موزع',
                  'pieces': damagedPieces,
                  'price_per_piece': pricePerPiece,
                  'total_value': totalValue,
                  'damage_date': _currentLoadDate,
                  'created_at': now,
                },
                where: 'id = ?',
                whereArgs: [existing.first['id']],
              );
            } else {
              await txn.delete(
                DBConstants.tableDistributorLoadDamage,
                where: 'id = ?',
                whereArgs: [existing.first['id']],
              );
            }
          } else if (damagedPieces > 0) {
            await txn.insert(DBConstants.tableDistributorLoadDamage, {
              'id': const Uuid().v4(),
              'distributor_id': widget.distributor.id,
              'load_id': _currentLoadId,
              'product_id': p.id,
              'damage_type': 'تالف موزع',
              'pieces': damagedPieces,
              'price_per_piece': pricePerPiece,
              'total_value': totalValue,
              'damage_date': _currentLoadDate,
              'created_at': now,
              'created_by': 'admin',
              'device_id': 'mobile',
              'sync_status': 'Pending',
            });
          }
        }
      });

      _calculateTotals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التالف وتقييم قيمته بنجاح'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ التالف: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ============ التصفية وإغلاق الحملة ============
  Future<void> _settleLoad() async {
    if (_currentLoadId == null) return;
    final cash = double.tryParse(_cashCtrl.text) ?? 0;

    try {
      await _distRepo.settleDistributor(
        distributorId: widget.distributor.id,
        loadId: _currentLoadId!,
        collectedCash: cash,
        totalLoadValue: _loadTotalValue,
        totalReturnedValue: _returnedTotalValue,
        totalDamagedValue: _damagedTotalValue,
        commissionPercent: widget.distributor.commissionPercent,
      );
      await _loadInitialData();
      await _loadLoadDetails(_currentLoadId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت تصفية وإغلاق الحملة بنجاح'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء التصفية: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('كشف حساب الموزع: ${widget.distributor.name}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقة بيانات الموزع
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _infoTile('الموزع', widget.distributor.name, Icons.person),
                            _infoTile('السيارة', widget.distributor.vehicle ?? '-', Icons.local_shipping),
                            _infoTile('العمولة', '%${widget.distributor.commissionPercent}', Icons.percent),
                          ]),
                          const Divider(),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _infoTile('الرصيد السابق', '${_prevBalance.toStringAsFixed(0)} ر.ي', Icons.history, color: Colors.orange),
                            _infoTile('الرصيد الحالي', '${widget.distributor.currentBalance.toStringAsFixed(0)} ر.ي', Icons.account_balance_wallet, color: Colors.red),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // أزرار التحكم بالنظام والتنقل
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _createNewLoad,
                          icon: const Icon(Icons.add_circle),
                          label: const Text('حملة جديدة'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveLoad,
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ التحميل'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_currentLoadId != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الحملة المفتوحة: ${_currentLoadId!.substring(0, 8)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('التاريخ: ${_currentLoadDate ?? ''}'),
                          Text('الحالة: ${_currentLoadStatus ?? ''}', style: TextStyle(color: _currentLoadStatus == 'مغلقة' ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // قسم التحميل
                  const Text('🚚 التحميل للحملة الحالية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._products.map((p) {
                    final totalQty = _parsePieces(_boxesControllers[p.id], _piecesControllers[p.id], p.piecesPerBox);
                    final price = _pricesForDistributor[p.id] ?? 0;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('سعر الوحدة: ${price.toStringAsFixed(0)} | سلة: ${p.piecesPerBox} قطعة', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _boxesControllers[p.id], decoration: const InputDecoration(labelText: 'سلال'), keyboardType: TextInputType.number, onChanged: (_) => setState(_calculateTotals))),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: _piecesControllers[p.id], decoration: const InputDecoration(labelText: 'قطع'), keyboardType: TextInputType.number, onChanged: (_) => setState(_calculateTotals))),
                              ],
                            ),
                            Text('الإجمالي: ${_piecesToDisplay(totalQty, p.piecesPerBox)} (${totalQty * price} ر.ي)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // قسم المرتجعات المستقل
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('🔄 مرتجع هذه الحملة فقط', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                              Text('إجمالي المرجوع: ${_returnedTotalValue.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                            ],
                          ),
                          const Divider(),
                          ..._products.map((p) {
                            final retQty = _parsePieces(_returnedBoxesCtrl[p.id], _returnedPiecesCtrl[p.id], p.piecesPerBox);
                            final price = _pricesForDistributor[p.id] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(p.name, style: const TextStyle(fontSize: 13))),
                                  Expanded(child: TextField(controller: _returnedBoxesCtrl[p.id], decoration: const InputDecoration(labelText: 'سلة مرتجع'), keyboardType: TextInputType.number, onChanged: (_) => setState(_calculateTotals))),
                                  const SizedBox(width: 4),
                                  Expanded(child: TextField(controller: _returnedPiecesCtrl[p.id], decoration: const InputDecoration(labelText: 'قطع مرتجع'), keyboardType: TextInputType.number, onChanged: (_) => setState(_calculateTotals))),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text('${retQty * price} ر.ي', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(onPressed: _saveReturns, icon: const Icon(Icons.save), label: const Text('حفظ المرتجعات وتحديث المخزن')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // قسم التالف المستقل مع التسعير
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('🗑️ تالف هذه الحملة فقط', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                              Text('إجمالي التالف: ${_damagedTotalValue.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                          const Divider(),
                          ..._products.map((p) {
                            final damPieces = _parsePieces(_damagedBoxesCtrl[p.id], _damagedPiecesCtrl[p.id], p.piecesPerBox);
                            final price = double.tryParse(_damagedPriceCtrl[p.id]?.text ?? '') ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(p.name, style: const TextStyle(fontSize: 13))),
                                  Expanded(child: TextField(controller: _damagedBoxesCtrl[p.id], decoration: const InputDecoration(labelText: 'سلة تالف'), keyboardType: TextInputType.number, onChanged: (_) => setState(_calculateTotals))),
                                  const SizedBox(width: 4),
                                  Expanded(child: TextField(controller: _damagedPiecesCtrl[p.id], decoration: const InputDecoration(labelText: 'قطع تالف'), keyboardType: TextInputType.number, onChanged: (_) => setState(_calculateTotals))),
                                  const SizedBox(width: 4),
                                  Expanded(child: TextField(controller: _damagedPriceCtrl[p.id], decoration: const InputDecoration(labelText: 'سعر القطعة'), keyboardType: TextInputType.number, onChanged: (_) => setState(_calculateTotals))),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text('${damPieces * price} ر.ي', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(onPressed: _saveDamaged, icon: const Icon(Icons.save), label: const Text('حفظ التالف والتسعير'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // النقد والتصفية
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💰 النقد والتصفية النهائية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(controller: _cashCtrl, decoration: const InputDecoration(labelText: 'النقد المسلم من الموزع'), keyboardType: TextInputType.number),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _settleLoad,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('إغلاق وتصفية الحملة'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size.fromHeight(45)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // تصفح أرشيف الحملات السابقة
                  const SizedBox(height: 24),
                  const Text('📦 أرشيف الحملات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _previousLoads.length,
                    itemBuilder: (context, index) {
                      final load = _previousLoads[index];
                      final isSelected = load['id'] == _currentLoadId;
                      return Card(
                        color: isSelected ? Colors.blue.shade100 : Colors.white,
                        child: ListTile(
                          leading: Icon(Icons.inventory, color: isSelected ? Colors.blue : Colors.grey),
                          title: Text('حملة بتاريخ: ${load['load_date'] ?? ''}'),
                          subtitle: Text('رقم الحملة: ${(load['id'] as String).substring(0, 8)} | الحالة: ${load['status'] ?? ''}'),
                          trailing: ElevatedButton(
                            onPressed: () => _loadLoadDetails(load['id'] as String),
                            child: const Text('عرض وتعديل'),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, {Color color = Colors.indigo}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
