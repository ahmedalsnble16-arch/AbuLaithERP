import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _filteredData = [];
  double _totalSales = 0;
  double _totalItems = 0;
  int _invoiceCount = 0;
  bool _isLoading = true;

  // الفلاتر
  String? _filterDate;
  String? _filterPaymentType;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery('''
      SELECT 
        s.id,
        s.invoice_number,
        s.customer_name,
        s.total,
        s.discount,
        s.grand_total,
        s.payment_type,
        s.payment_status,
        s.sale_date,
        s.created_at,
        COUNT(DISTINCT si.id) as item_count,
        SUM(si.quantity) as total_quantity
      FROM ${DBConstants.tableSales} s
      LEFT JOIN ${DBConstants.tableSaleItems} si ON s.id = si.sale_id
      WHERE s.deleted = 0
      GROUP BY s.id
      ORDER BY s.sale_date DESC, s.created_at DESC
      LIMIT 200
    ''');

    double totalSales = 0;
    double totalItems = 0;
    for (var row in result) {
      totalSales += (row['grand_total'] as num?)?.toDouble() ?? 0;
      totalItems += (row['total_quantity'] as num?)?.toDouble() ?? 0;
    }

    setState(() {
      _data = result;
      _filteredData = result;
      _totalSales = totalSales;
      _totalItems = totalItems;
      _invoiceCount = result.length;
      _isLoading = false;
    });
  }

  /// عرض تفاصيل فاتورة محددة
  Future<void> _showInvoiceDetails(Map<String, dynamic> invoice) async {
    final db = await DatabaseHelper().database;
    final items = await db.rawQuery('''
      SELECT si.*, p.name as product_name
      FROM ${DBConstants.tableSaleItems} si
      INNER JOIN ${DBConstants.tableProducts} p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [invoice['id']]);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('فاتورة ${invoice['invoice_number']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('العميل', (invoice['customer_name'] ?? 'عميل نقدي').toString()),
              _detailRow('التاريخ', (invoice['sale_date'] ?? '-').toString()),
              _detailRow('طريقة الدفع', (invoice['payment_type'] ?? '-').toString()),
              _detailRow('حالة الدفع', (invoice['payment_status'] ?? '-').toString()),
              _detailRow('الإجمالي', '${invoice['total']}'),
              _detailRow('الخصم', '${invoice['discount']}'),
              _detailRow('الصافي', '${invoice['grand_total']}'),
              const Divider(),
              const Text('بنود الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...items.map((item) => ListTile(
                dense: true,
                title: Text((item['product_name'] ?? '').toString()),
                subtitle: Text('الكمية: ${item['quantity']} × ${item['unit_price']}'),
                trailing: Text('${item['total']}'),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _applyFilters() {
    var list = _data;
    if (_filterDate != null) {
      list = list.where((d) => d['sale_date'] == _filterDate).toList();
    }
    if (_filterPaymentType != null) {
      list = list.where((d) => d['payment_type'] == _filterPaymentType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((d) =>
          (d['customer_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d['invoice_number'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    setState(() => _filteredData = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير المبيعات'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      _statCard('عدد الفواتير', '$_invoiceCount', AppTheme.primaryColor),
                      _statCard('إجمالي المبيعات', _totalSales.toStringAsFixed(2), AppTheme.successColor),
                      _statCard('إجمالي القطع', '${_totalItems.toInt()}', AppTheme.warningColor),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String?>(
                          hint: const Text('طريقة الدفع'),
                          value: _filterPaymentType,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('الكل')),
                            DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                            DropdownMenuItem(value: 'آجل', child: Text('آجل')),
                          ],
                          onChanged: (v) {
                            _filterPaymentType = v;
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'بحث (عميل/فاتورة)...',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) {
                            _searchQuery = v;
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredData.isEmpty
                      ? const Center(child: Text('لا توجد مبيعات'))
                      : ListView.builder(
                          itemCount: _filteredData.length,
                          itemBuilder: (context, index) {
                            final sale = _filteredData[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: sale['payment_type'] == 'نقدي' ? AppTheme.successColor : AppTheme.warningColor,
                                  child: Icon(
                                    sale['payment_type'] == 'نقدي' ? Icons.payments : Icons.receipt_long,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text((sale['invoice_number'] ?? '').toString()),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('العميل: ${(sale['customer_name'] ?? "نقدي").toString()}'),
                                    Text('${sale['sale_date']} | ${sale['payment_type']} | قطع: ${sale['total_quantity']}'),
                                  ],
                                ),
                                trailing: Text(
                                  '${sale['grand_total']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                                onTap: () => _showInvoiceDetails(sale),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
