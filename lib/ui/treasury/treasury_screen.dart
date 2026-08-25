import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/treasury_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../data/repositories/distributor_repository.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final TreasuryRepository _repo = TreasuryRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final SupplierRepository _supplierRepo = SupplierRepository();
  final DistributorRepository _distributorRepo = DistributorRepository();

  // إحصائيات الخزنة
  double _currentBalance = 0;
  double _todayReceipts = 0;
  double _todayPayments = 0;
  double _openingBalance = 0;
  double _netMovement = 0;

  // قوائم الجهات
  List<dynamic> _customers = [];
  List<dynamic> _suppliers = [];
  List<dynamic> _distributors = [];

  // الحركات
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  // الفلاتر
  String? _filterType;
  String? _filterSource;
  String? _filterDate;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentBalance = await _repo.getCurrentBalance();
      _todayReceipts = await _repo.getTodayReceipts();
      _todayPayments = await _repo.getTodayPayments();
      _openingBalance = await _repo.getOpeningBalance();
      _netMovement = _todayReceipts - _todayPayments;

      _customers = await _customerRepo.getAll();
      _suppliers = await _supplierRepo.getAll();
      _distributors = await _distributorRepo.getAll();
      _transactions = await _repo.getAll();
    } catch (e) {
      debugPrint('Error loading treasury: $e');
    }
    setState(() => _isLoading = false);
  }

  // ============ إضافة حركة مالية ============
  Future<void> _showAddDialog({required String type}) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? sourceModule;
    String? sourceId;
    String? sourceName;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(type == 'قبض' ? '💰 سند قبض' : '💸 سند صرف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'المبلغ *'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'البيان'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: 'المصدر'),
                  value: sourceModule,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('بدون مصدر')),
                    DropdownMenuItem(value: 'عميل', child: Text('عميل')),
                    DropdownMenuItem(value: 'مورد', child: Text('مورد')),
                    DropdownMenuItem(value: 'موزع', child: Text('موزع')),
                    DropdownMenuItem(value: 'معرض', child: Text('معرض')),
                    DropdownMenuItem(value: 'إنتاج', child: Text('إنتاج')),
                    DropdownMenuItem(value: 'مصروف', child: Text('مصروف')),
                    DropdownMenuItem(value: 'يدوي', child: Text('إضافة يدوية')),
                  ],
                  onChanged: (val) => setStateDialog(() => sourceModule = val),
                ),
                if (sourceModule == 'عميل')
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(labelText: 'اختر العميل'),
                    items: _customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (val) => setStateDialog(() => sourceId = val),
                  ),
                if (sourceModule == 'مورد')
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(labelText: 'اختر المورد'),
                    items: _suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (val) => setStateDialog(() => sourceId = val),
                  ),
                if (sourceModule == 'موزع')
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(labelText: 'اختر الموزع'),
                    items: _distributors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                    onChanged: (val) => setStateDialog(() => sourceId = val),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('أدخل مبلغاً صحيحاً')),
                  );
                  return;
                }

                if (type == 'قبض') {
                  await _repo.addReceipt(
                    amount: amount,
                    sourceModule: sourceModule,
                    sourceId: sourceId,
                    note: noteCtrl.text,
                    createdBy: 'admin',
                  );

                  // خصم من رصيد العميل إذا كان المصدر عميل
                  if (sourceModule == 'عميل' && sourceId != null) {
                    final customer = _customers.firstWhere((c) => c.id == sourceId);
                    await _customerRepo.update(customer);
                  }
                  // خصم من رصيد الموزع إذا كان المصدر موزع
                  if (sourceModule == 'موزع' && sourceId != null) {
                    final distributor = _distributors.firstWhere((d) => d.id == sourceId);
                    await _distributorRepo.updateDistributor(distributor);
                  }
                } else {
                  await _repo.addPayment(
                    amount: amount,
                    sourceModule: sourceModule,
                    sourceId: sourceId,
                    note: noteCtrl.text,
                    createdBy: 'admin',
                  );

                  // خصم من رصيد المورد إذا كان المصدر مورد
                  if (sourceModule == 'مورد' && sourceId != null) {
                    final supplier = _suppliers.firstWhere((s) => s.id == sourceId);
                    await _supplierRepo.update(supplier);
                  }
                }

                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == true) _loadData();
  }

  // ============ عرض تفاصيل الحركة ============
  void _showTransactionDetails(dynamic transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفاصيل الحركة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('رقم العملية', transaction.transactionNumber),
            _detailRow('النوع', transaction.transactionType),
            _detailRow('المبلغ', '${transaction.amount}'),
            _detailRow('البيان', transaction.note ?? '-'),
            _detailRow('المصدر', transaction.sourceModule ?? '-'),
            _detailRow('التاريخ', transaction.transactionDate),
            _detailRow('المستخدم', transaction.createdBy ?? '-'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  // ============ الفلترة والبحث ============
  List<dynamic> get _filteredTransactions {
    var list = _transactions;
    if (_filterType != null) {
      list = list.where((t) => t.transactionType == _filterType).toList();
    }
    if (_filterSource != null) {
      list = list.where((t) => t.sourceModule == _filterSource).toList();
    }
    if (_filterDate != null) {
      list = list.where((t) => t.transactionDate == _filterDate).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((t) =>
          (t.note ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.transactionNumber.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخزنة'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ============ البطاقات الإحصائية ============
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildSummaryCard('💰 الرصيد الحالي', _currentBalance, AppTheme.primaryColor, isBig: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSummaryCard('📥 مقبوضات اليوم', _todayReceipts, AppTheme.successColor),
                          _buildSummaryCard('📤 مدفوعات اليوم', _todayPayments, AppTheme.errorColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildSummaryCard('🌅 رصيد البداية', _openingBalance, AppTheme.warningColor),
                          _buildSummaryCard('📊 صافي الحركة', _netMovement, _netMovement >= 0 ? AppTheme.successColor : AppTheme.errorColor),
                        ],
                      ),
                    ],
                  ),
                ),

                // ============ أزرار الإضافة ============
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddDialog(type: 'قبض'),
                          icon: const Icon(Icons.add_circle),
                          label: const Text('قبض'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddDialog(type: 'صرف'),
                          icon: const Icon(Icons.remove_circle),
                          label: const Text('صرف'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // ============ الفلاتر ============
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String?>(
                          hint: const Text('النوع'),
                          value: _filterType,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('الكل')),
                            DropdownMenuItem(value: 'قبض', child: Text('قبض')),
                            DropdownMenuItem(value: 'صرف', child: Text('صرف')),
                          ],
                          onChanged: (v) => setState(() => _filterType = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String?>(
                          hint: const Text('المصدر'),
                          value: _filterSource,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('الكل')),
                            DropdownMenuItem(value: 'عميل', child: Text('عميل')),
                            DropdownMenuItem(value: 'مورد', child: Text('مورد')),
                            DropdownMenuItem(value: 'موزع', child: Text('موزع')),
                            DropdownMenuItem(value: 'معرض', child: Text('معرض')),
                            DropdownMenuItem(value: 'إنتاج', child: Text('إنتاج')),
                            DropdownMenuItem(value: 'مصروف', child: Text('مصروف')),
                            DropdownMenuItem(value: 'يدوي', child: Text('يدوي')),
                          ],
                          onChanged: (v) => setState(() => _filterSource = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'بحث...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  ),
                ),

                // ============ جدول الحركات ============
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? const Center(child: Text('لا توجد حركات'))
                      : ListView.builder(
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _filteredTransactions[index];
                            final isReceipt = t.transactionType == 'قبض';
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isReceipt ? AppTheme.successColor.withAlpha(30) : AppTheme.errorColor.withAlpha(30),
                                  child: Icon(
                                    isReceipt ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isReceipt ? AppTheme.successColor : AppTheme.errorColor,
                                  ),
                                ),
                                title: Text(t.note ?? 'بدون بيان'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${t.transactionNumber} | ${t.transactionDate}'),
                                    if (t.sourceModule != null) Text('المصدر: ${t.sourceModule}'),
                                  ],
                                ),
                                trailing: Text(
                                  '${isReceipt ? "+" : "-"}${t.amount}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isReceipt ? AppTheme.successColor : AppTheme.errorColor,
                                  ),
                                ),
                                onTap: () => _showTransactionDetails(t),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, {bool isBig = false}) {
    return Expanded(
      child: Card(
        color: color.withAlpha(15),
        child: Padding(
          padding: EdgeInsets.all(isBig ? 16 : 12),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: isBig ? 14 : 12)),
              const SizedBox(height: 4),
              Text(
                amount.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: isBig ? 24 : 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
