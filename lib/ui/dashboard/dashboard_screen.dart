import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/auth/session_manager.dart';
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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();
    final user = session.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await session.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryColor,
                      child: Icon(Icons.person, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً ${user?.fullName ?? "المستخدم"}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          const Text('مدير النظام', style: TextStyle(color: AppTheme.textSecondaryColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('الوصول السريع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                _buildCard(context, Icons.inventory_2, 'المنتجات', AppTheme.primaryColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen()))),
                _buildCard(context, Icons.grain, 'المواد الخام', Colors.brown, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaterialsScreen()))),
                _buildCard(context, Icons.factory, 'الإنتاج', Colors.deepOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionScreen()))),
                _buildCard(context, Icons.warehouse, 'المخزن', AppTheme.primaryColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseScreen()))),
                _buildCard(context, Icons.store, 'المعرض', Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShowroomScreen()))),
                _buildCard(context, Icons.account_balance_wallet, 'الخزنة', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TreasuryScreen()))),
                _buildCard(context, Icons.money_off, 'المصروفات', Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()))),
                _buildCard(context, Icons.local_shipping, 'الموزعون', Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DistributorsScreen()))),
                _buildCard(context, Icons.assessment, 'التقارير', Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsMenuScreen()))),
                _buildCard(context, Icons.people, 'العملاء', Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()))),
                _buildCard(context, Icons.business, 'الموردين', Colors.deepPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()))),
                _buildCard(context, Icons.shopping_cart, 'المشتريات', Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasesScreen()))),
                _buildCard(context, Icons.badge, 'العمال', Colors.lightBlue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkersScreen()))),
                _buildCard(context, Icons.sync, 'المزامنة', Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen()))),
                _buildCard(context, Icons.settings, 'الإعدادات', Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                _buildCard(context, Icons.history, 'سجل العمليات', AppTheme.textSecondaryColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen()))),
                _buildCard(context, Icons.backup, 'نسخ احتياطي', AppTheme.warningColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
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
              CircleAvatar(radius: 18, backgroundColor: color.withAlpha(30), child: Icon(icon, color: color, size: 20)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
