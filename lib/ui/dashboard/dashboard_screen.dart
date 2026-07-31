import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/auth/session_manager.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/db_constants.dart';
import '../products/products_screen.dart';
import '../raw_materials/materials_screen.dart';
import '../production/production_screen.dart';
import '../warehouse/warehouse_screen.dart';
import '../showroom/showroom_screen.dart';
import '../treasury/treasury_screen.dart';
import '../expenses/expenses_screen.dart';
import '../distributors/distributors_screen.dart';
import '../reports/reports_menu_screen.dart';
import '../sync/sync_screen.dart';
import '../customers/customers_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../purchases/purchases_screen.dart';
import '../workers/workers_screen.dart';
import '../settings/settings_screen.dart';
import '../audit/audit_log_screen.dart';
import '../backup/backup_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _balance = 0;
  int _stockValue = 0;
  int _todayProduction = 0;
  double _todaySales = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentActivities = [];
  String _username = 'المستخدم';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper().database;

      // رصيد الخزنة
      final balanceResult = await db.rawQuery('''
        SELECT COALESCE(SUM(CASE WHEN transaction_type = 'قبض' THEN amount ELSE -amount END), 0) as balance
        FROM ${DBConstants.tableTreasury}
        WHERE deleted = 0
      ''');
      _balance = (balanceResult.first['balance'] as num?)?.toDouble() ?? 0.0;

      // قيمة المخزون (عدد القطع)
      final stockResult = await db.rawQuery('''
        SELECT COALESCE(SUM(quantity_pieces), 0) as total
        FROM ${DBConstants.tableStock}
      ''');
      _stockValue = (stockResult.first['total'] as num?)?.toInt() ?? 0;

      // إنتاج اليوم
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final prodResult = await db.rawQuery('''
        SELECT COALESCE(SUM(good_pieces), 0) as total
        FROM ${DBConstants.tableProductionBatches}
        WHERE production_date = ? AND deleted = 0
      ''', [today]);
      _todayProduction = (prodResult.first['total'] as num?)?.toInt() ?? 0;

      // مبيعات اليوم
      final salesResult = await db.rawQuery('''
        SELECT COALESCE(SUM(grand_total), 0) as total
        FROM ${DBConstants.tableSales}
        WHERE sale_date = ? AND deleted = 0
      ''', [today]);
      _todaySales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;

      // آخر العمليات
      final auditLogs = await db.query(
        DBConstants.tableAuditLogs,
        orderBy: 'created_at DESC',
        limit: 5,
      );
      _recentActivities = auditLogs;

      // اسم المستخدم
      final userData = await SessionManager.getUser();
      _username = userData['username'] ?? 'المستخدم';
    } catch (e) {
      // في حال وجود خطأ، تبقى القيم الافتراضية
    }
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await SessionManager.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: AppDrawer(
        username: _username,
        onLogout: _logout,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقة الترحيب
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.primaryColor,
                              child: Icon(Icons.person,
                                  size: 32, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مرحباً $_username',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('مدير النظام',
                                      style: TextStyle(
                                          color: AppTheme.textSecondaryColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // البطاقات الإحصائية
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _buildStatCard('رصيد الخزنة', '${_balance.toStringAsFixed(0)} ر.ي',
                            Icons.account_balance_wallet, AppTheme.successColor),
                        _buildStatCard('قيمة المخزون', '$_stockValue قطعة',
                            Icons.inventory_2, AppTheme.primaryColor),
                        _buildStatCard('إنتاج اليوم', '$_todayProduction قطعة',
                            Icons.factory, AppTheme.warningColor),
                        _buildStatCard('مبيعات اليوم', '${_todaySales.toStringAsFixed(0)} ر.ي',
                            Icons.shopping_cart, AppTheme.errorColor),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // الوصول السريع
                    const Text('الوصول السريع',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                      children: [
                        _buildQuickCard(Icons.inventory_2, 'المنتجات',
                            AppTheme.primaryColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()));
                        }),
                        _buildQuickCard(Icons.grain, 'المواد الخام',
                            Colors.brown, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen()));
                        }),
                        _buildQuickCard(Icons.factory, 'الإنتاج',
                            Colors.deepOrange, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen()));
                        }),
                        _buildQuickCard(Icons.warehouse, 'المخزن',
                            AppTheme.primaryColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseScreen()));
                        }),
                        _buildQuickCard(Icons.store, 'المعرض',
                            Colors.teal, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ShowroomScreen()));
                        }),
                        _buildQuickCard(Icons.account_balance_wallet, 'الخزنة',
                            Colors.green, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TreasuryScreen()));
                        }),
                        _buildQuickCard(Icons.money_off, 'المصروفات',
                            Colors.orange, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                        }),
                        _buildQuickCard(Icons.local_shipping, 'الموزعون',
                            Colors.indigo, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DistributorsScreen()));
                        }),
                        _buildQuickCard(Icons.assessment, 'التقارير',
                            Colors.purple, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsMenuScreen()));
                        }),
                        _buildQuickCard(Icons.people, 'العملاء',
                            Colors.blue, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
                        }),
                        _buildQuickCard(Icons.business, 'الموردين',
                            Colors.deepPurple, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()));
                        }),
                        _buildQuickCard(Icons.shopping_cart, 'المشتريات',
                            Colors.blueGrey, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen()));
                        }),
                        _buildQuickCard(Icons.badge, 'العمال',
                            Colors.lightBlue, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkersScreen()));
                        }),
                        _buildQuickCard(Icons.sync, 'المزامنة',
                            Colors.cyan, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen()));
                        }),
                        _buildQuickCard(Icons.settings, 'الإعدادات',
                            Colors.grey, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        }),
                        _buildQuickCard(Icons.history, 'سجل العمليات',
                            AppTheme.textSecondaryColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen()));
                        }),
                        _buildQuickCard(Icons.backup, 'نسخ احتياطي',
                            AppTheme.warningColor, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()));
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // آخر العمليات
                    const Text('آخر العمليات',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_recentActivities.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('لا توجد عمليات حتى الآن')),
                        ),
                      )
                    else
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('الوقت')),
                              DataColumn(label: Text('الوحدة')),
                              DataColumn(label: Text('العملية')),
                            ],
                            rows: _recentActivities.map((log) {
                              return DataRow(cells: [
                                DataCell(Text(log['created_at']?.toString().substring(0, 16) ?? '')),
                                DataCell(Text(log['module'] ?? '')),
                                DataCell(Text(log['action'] ?? '')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondaryColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withAlpha(30),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== القائمة الجانبية ==========
class AppDrawer extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.username,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // رأس القائمة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppTheme.primaryColor,
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'مدير النظام',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            // عناصر القائمة
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(context, Icons.dashboard, 'لوحة التحكم', () {
                    Navigator.pop(context);
                  }),
                  _drawerItem(context, Icons.inventory_2, 'المنتجات', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()));
                  }),
                  _drawerItem(context, Icons.grain, 'المواد الخام', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen()));
                  }),
                  _drawerItem(context, Icons.factory, 'الإنتاج', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen()));
                  }),
                  _drawerItem(context, Icons.warehouse, 'المخزن', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseScreen()));
                  }),
                  _drawerItem(context, Icons.store, 'المعرض', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ShowroomScreen()));
                  }),
                  _drawerItem(context, Icons.account_balance_wallet, 'الخزنة', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TreasuryScreen()));
                  }),
                  _drawerItem(context, Icons.money_off, 'المصروفات', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                  }),
                  _drawerItem(context, Icons.local_shipping, 'الموزعون', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DistributorsScreen()));
                  }),
                  _drawerItem(context, Icons.assessment, 'التقارير', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsMenuScreen()));
                  }),
                  _drawerItem(context, Icons.people, 'العملاء', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
                  }),
                  _drawerItem(context, Icons.business, 'الموردين', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()));
                  }),
                  _drawerItem(context, Icons.shopping_cart, 'المشتريات', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen()));
                  }),
                  _drawerItem(context, Icons.badge, 'العمال', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkersScreen()));
                  }),
                  _drawerItem(context, Icons.sync, 'المزامنة', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen()));
                  }),
                  _drawerItem(context, Icons.settings, 'الإعدادات', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  }),
                  _drawerItem(context, Icons.history, 'سجل العمليات', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen()));
                  }),
                  _drawerItem(context, Icons.backup, 'نسخ احتياطي', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()));
                  }),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                    title: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.errorColor)),
                    onTap: () {
                      Navigator.pop(context);
                      onLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      onTap: onTap,
    );
  }
}
