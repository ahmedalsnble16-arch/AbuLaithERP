import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../data/repositories/system_management_repository.dart';

class DataDeletionScreen extends StatefulWidget {
  const DataDeletionScreen({super.key});

  @override
  State<DataDeletionScreen> createState() => _DataDeletionScreenState();
}

class _DataDeletionScreenState extends State<DataDeletionScreen> {
  final SystemManagementRepository _repo = SystemManagementRepository();
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _allTables = [];
  List<String> _filteredTables = [];
  Map<String, int> _recordCounts = {};
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showTreeView = true;

  // الهيكل الشجري للأقسام
  final Map<String, List<String>> _sectionsMap = {
    'لوحة التحكم': ['dashboard'],
    'المنتجات': ['products', 'categories'],
    'المواد الخام': ['raw_materials', 'raw_stock', 'recipes'],
    'الإنتاج': ['production_batches', 'production_compare', 'production_plans'],
    'المبيعات': ['sales', 'sale_items'],
    'المشتريات': ['purchases', 'purchase_items'],
    'العملاء': ['customers'],
    'الموردون': ['suppliers'],
    'الموزعون': ['distributors', 'distributor_loads', 'distributor_load_items', 'distributor_load_returns', 'distributor_load_damage', 'distributor_damage_prices', 'distributor_product_prices', 'distributor_returns'],
    'المعرض': ['showroom_stock', 'showroom_movements', 'showroom_daily_entries', 'showroom_daily_account', 'showroom_daily_expenses', 'showroom_khat'],
    'العمال': ['workers', 'worker_accounts', 'worker_attendance', 'worker_daily_expenses'],
    'الشركاء': ['partners', 'partner_transactions'],
    'الخزنة': ['treasury'],
    'المصروفات': ['expenses'],
    'الإصلاحات': ['repairs', 'repair_types'],
    'الجرد': ['inventory_counts', 'daily_remaining'],
    'المستخدمون': ['users', 'roles', 'permissions', 'role_permissions'],
    'الإعدادات': ['settings', 'devices', 'dynamic_configurations', 'system_archives'],
    'النظام': ['sync_queue', 'audit_logs', 'error_logs', 'backup_history'],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tables = await _repo.getTablesList();
      final counts = <String, int>{};
      for (var table in tables) {
        counts[table] = await _repo.getRecordCount(table);
      }
      setState(() {
        _allTables = tables;
        _filteredTables = List.from(tables);
        _recordCounts = counts;
      });
    } catch (e) {
      _showError('خطأ في تحميل الجداول: $e');
    }
    setState(() => _isLoading = false);
  }

  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTables = List.from(_allTables);
      } else {
        _filteredTables = _allTables.where((t) => t.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  Future<void> _showClearDialog(String tableName, int recordCount) async {
    final passwordCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    // تحديد إذا كان الجدول مالياً
    final isFinancialTable = [
      'treasury', 'expenses', 'sales', 'sale_items', 'purchases', 'purchase_items',
      'worker_accounts', 'partner_transactions', 'distributor_loads', 'distributor_load_returns',
      'distributor_load_damage', 'repairs', 'showroom_daily_account', 'showroom_daily_expenses',
    ].contains(tableName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isFinancialTable ? Icons.warning_amber : Icons.warning,
              color: isFinancialTable ? Colors.orange : AppTheme.errorColor,
            ),
            const SizedBox(width: 8),
            Text('${isFinancialTable ? 'إلغاء مالي آمن' : 'تصفير'} $tableName'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isFinancialTable ? Colors.orange : AppTheme.errorColor).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFinancialTable
                      ? '⚠️ هذا جدول مالي!\n\nسيتم إلغاء $recordCount سجل بطريقة عكسية (Void) للحفاظ على سلامة الحسابات.\n\nسيتم أرشفة البيانات قبل الإلغاء.'
                      : '⚠️ سيتم تصفير $recordCount سجل من جدول $tableName.\n\nسيتم أرشفة البيانات قبل التصفير.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              if (isFinancialTable) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🛡️ الحماية المالية:\n- سيتم إنشاء حركات عكسية بدلاً من الحذف المباشر\n- سيتم تصحيح أرصدة الخزنة والحسابات\n- سيتم تسجيل كل عملية في سجل التدقيق',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة مرور المدير *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (سبب العملية)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isFinancialTable ? Colors.orange : AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (passwordCtrl.text.isEmpty) {
                _showError('يرجى إدخال كلمة مرور المدير');
                return;
              }
              try {
                if (isFinancialTable) {
                  // استخدام الإلغاء العكسي للجداول المالية
                  await _repo.voidFinancialTable(
                    tableName: tableName,
                    adminPassword: passwordCtrl.text,
                    notes: notesCtrl.text,
                  );
                } else {
                  await _repo.clearTable(
                    tableName: tableName,
                    adminPassword: passwordCtrl.text,
                    notes: notesCtrl.text,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
                _showSuccess(isFinancialTable ? 'تم الإلغاء المالي بنجاح' : 'تم التصفير بنجاح');
              } catch (e) {
                _showError('فشل العملية: $e');
              }
            },
            child: Text(isFinancialTable ? 'تأكيد الإلغاء المالي' : 'تأكيد التصفير'),
          ),
        ],
      ),
    );

    if (confirmed == true) _loadData();
  }

  Future<void> _showDeleteByPeriodDialog(String tableName) async {
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String dateColumn = 'created_at';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف سجلات من $tableName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fromCtrl,
                decoration: const InputDecoration(
                  labelText: 'من تاريخ (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.date_range),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: toCtrl,
                decoration: const InputDecoration(
                  labelText: 'إلى تاريخ (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.date_range),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة مرور المدير *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              if (fromCtrl.text.isEmpty || toCtrl.text.isEmpty) {
                _showError('يرجى إدخال الفترة الزمنية');
                return;
              }
              try {
                final from = DateTime.parse(fromCtrl.text);
                final to = DateTime.parse(toCtrl.text);
                await _repo.deleteRecordsByPeriod(
                  tableName: tableName,
                  dateColumn: dateColumn,
                  from: from,
                  to: to,
                  adminPassword: passwordCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
                _showSuccess('تم حذف السجلات بنجاح');
              } catch (e) {
                _showError('فشل الحذف: $e');
              }
            },
            child: const Text('حذف السجلات'),
          ),
        ],
      ),
    );

    if (result == true) _loadData();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // البحث وتبديل العرض
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _applySearch,
                decoration: InputDecoration(
                  hintText: 'بحث عن جدول...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applySearch('');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showTreeView = true),
                    icon: const Icon(Icons.account_tree),
                    label: const Text('شجري'),
                    style: TextButton.styleFrom(
                      foregroundColor: _showTreeView ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _showTreeView = false),
                    icon: const Icon(Icons.list),
                    label: const Text('جدولي'),
                    style: TextButton.styleFrom(
                      foregroundColor: !_showTreeView ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // المحتوى
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _showTreeView
                  ? _buildTreeView()
                  : _buildTableView(),
        ),
      ],
    );
  }

  Widget _buildTreeView() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: _sectionsMap.entries.map((section) {
        final sectionTables = section.value.where((t) => _allTables.contains(t)).toList();
        if (sectionTables.isEmpty) return const SizedBox.shrink();
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ExpansionTile(
            leading: Icon(
              _getSectionIcon(section.key),
              color: AppTheme.primaryColor,
            ),
            title: Text(section.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${sectionTables.length} جداول'),
            children: sectionTables.map((table) {
              final count = _recordCounts[table] ?? 0;
              return ListTile(
                leading: const SizedBox(width: 16),
                title: Text(table),
                subtitle: Text('عدد السجلات: $count'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.date_range, color: AppTheme.primaryColor),
                      onPressed: count > 0 ? () => _showDeleteByPeriodDialog(table) : null,
                      tooltip: 'حذف حسب فترة',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
                      onPressed: count > 0 ? () => _showClearDialog(table, count) : null,
                      tooltip: 'تصفير/إلغاء',
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTableView() {
    return _filteredTables.isEmpty
        ? const Center(child: Text('لا توجد جداول'))
        : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _filteredTables.length,
            itemBuilder: (context, index) {
              final table = _filteredTables[index];
              final count = _recordCounts[table] ?? 0;
              final isFinancial = [
                'treasury', 'expenses', 'sales', 'purchases', 'worker_accounts',
                'partner_transactions', 'repairs', 'distributor_loads',
              ].contains(table);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    isFinancial ? Icons.account_balance_wallet : Icons.table_chart,
                    color: isFinancial ? Colors.orange : AppTheme.warningColor,
                  ),
                  title: Text(table, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('عدد السجلات: $count${isFinancial ? ' | مالي' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.date_range, color: AppTheme.primaryColor),
                        onPressed: count > 0 ? () => _showDeleteByPeriodDialog(table) : null,
                      ),
                      IconButton(
                        icon: Icon(
                          isFinancial ? Icons.undo : Icons.delete_forever,
                          color: isFinancial ? Colors.orange : AppTheme.errorColor,
                        ),
                        onPressed: count > 0 ? () => _showClearDialog(table, count) : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'المنتجات': return Icons.inventory;
      case 'المواد الخام': return Icons.grain;
      case 'الإنتاج': return Icons.factory;
      case 'المبيعات': return Icons.point_of_sale;
      case 'المشتريات': return Icons.shopping_cart;
      case 'العملاء': return Icons.people;
      case 'الموردون': return Icons.local_shipping;
      case 'الموزعون': return Icons.delivery_dining;
      case 'المعرض': return Icons.storefront;
      case 'العمال': return Icons.engineering;
      case 'الشركاء': return Icons.handshake;
      case 'الخزنة': return Icons.account_balance;
      case 'المصروفات': return Icons.money_off;
      case 'الإصلاحات': return Icons.build;
      case 'الجرد': return Icons.inventory_2;
      case 'المستخدمون': return Icons.admin_panel_settings;
      case 'الإعدادات': return Icons.settings;
      case 'النظام': return Icons.dns;
      default: return Icons.folder;
    }
  }
}
