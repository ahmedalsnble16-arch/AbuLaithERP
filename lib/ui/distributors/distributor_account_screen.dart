import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
  Map<String, TextEditingController> _boxesControllers = {};
  Map<String, TextEditingController> _piecesControllers = {};
  Map<String, double> _pricesForDistributor = {}; // سعر خاص لكل منتج لهذا الموزع
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
      
      // 1. جلب المنتجات النشطة
      final products = await _productRepo.getAll();
      
      // 2. جلب الأسعار الخاصة بالموزع (من جدول distributor_prices إن وجد، وإلا فسعر الجملة الافتراضي)
      // في الوقت الحالي نستخدم سعر الجملة للمنتج كسعر افتراضي للموزع
      for (var p in products) {
        _pricesForDistributor[p.id] = p.wholesalePrice;
      }
      
      // 3. جلب الرصيد المرحل (من حقل current_balance للموزع)
      _prevBalance = widget.distributor.currentBalance;
      
      // 4. جلب الحملات السابقة
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

  // ============ حساب الكميات ============
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

  // ============ حساب المبالغ ============
  double _loadValue(String productId) {
    final price = _pricesForDistributor[productId] ?? 0;
    return _totalPieces(productId) * price;
  }

  double get _totalLoadValue => _products.fold(0, (sum, p) => sum + _loadValue(p.id));
  double get _discountValue => _totalLoadValue * (widget.distributor.commissionPercent / 100);
  double get _totalRequired => _prevBalance + _totalLoadValue;
  double get _finalBalance => _totalRequired - _discountValue - _collectedCash - _returnedValue - _damagedValue;

  // ============ حفظ الحملة ============
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

    // 1. إنشاء الحملة
    await _distRepo.createLoad(
      distributorId: widget.distributor.id,
      items: items,
    );

    // 2. تحديث رصيد الموزع
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
                  // ========== رأس الكشف ==========
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

                  // ========== الحملة الحالية ==========
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

                  // ========== صندوق الحساب ==========
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
                          TextField(
                            decoration: const InputDecoration(labelText: 'قيمة المرجوع', prefixIcon: Icon(Icons.undo)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() => _returnedValue = double.tryParse(v) ?? 0),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: const InputDecoration(labelText: 'قيمة التالف', prefixIcon: Icon(Icons.delete)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() => _damagedValue = double.tryParse(v) ?? 0),
                          ),
                          const Divider(),
                          _calcRow('💰 الرصيد النهائي (يرحل للحملة التالية)', '${_finalBalance.toStringAsFixed(0)} ر.ي', isBold: true, color: AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _saveLoad, icon: const Icon(Icons.save), label: const Text('حفظ الحملة')),

                  // ========== الحملات السابقة ==========
                  const SizedBox(height: 24),
                  const Text('📦 الحملات السابقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(_previousLoads.map((load) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.receipt, color: Colors.white)),
                      title: Text('حملة ${load['load_date'] ?? ''}'),
                      subtitle: Text('الحالة: ${load['status'] ?? 'مغلقة'}'),
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
