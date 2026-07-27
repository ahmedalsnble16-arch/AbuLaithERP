import 'package:flutter/material.dart';
import '../ui/auth/login_screen.dart';
import '../ui/dashboard/dashboard_screen.dart';
import '../ui/products/products_screen.dart';
import '../ui/raw_materials/materials_screen.dart';
import '../ui/production/production_screen.dart';
import '../ui/warehouse/warehouse_screen.dart';
import '../ui/showroom/showroom_screen.dart';
import '../ui/treasury/treasury_screen.dart';
import '../ui/expenses/expenses_screen.dart';
import '../ui/distributors/distributors_screen.dart';
import '../ui/reports/reports_menu_screen.dart';
import '../ui/sync/sync_screen.dart';
import '../ui/customers/customers_screen.dart';
import '../ui/suppliers/suppliers_screen.dart';
import '../ui/purchases/purchases_screen.dart';
import '../ui/workers/workers_screen.dart';
import '../ui/settings/settings_screen.dart';
import '../ui/audit/audit_log_screen.dart';
import '../ui/backup/backup_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    '/': (context) => const LoginScreen(),
    '/dashboard': (context) => const DashboardScreen(),
    '/products': (context) => const ProductsScreen(),
    '/raw-materials': (context) => const MaterialsScreen(),
    '/production': (context) => const ProductionScreen(),
    '/warehouse': (context) => const WarehouseScreen(),
    '/showroom': (context) => const ShowroomScreen(),
    '/treasury': (context) => const TreasuryScreen(),
    '/expenses': (context) => const ExpensesScreen(),
    '/distributors': (context) => const DistributorsScreen(),
    '/reports': (context) => const ReportsMenuScreen(),
    '/sync': (context) => const SyncScreen(),
    '/customers': (context) => const CustomersScreen(),
    '/suppliers': (context) => const SuppliersScreen(),
    '/purchases': (context) => const PurchasesScreen(),
    '/workers': (context) => const WorkersScreen(),
    '/settings': (context) => const SettingsScreen(),
    '/audit': (context) => const AuditLogScreen(),
    '/backup': (context) => const BackupScreen(),
  };

  static const String login = '/';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String rawMaterials = '/raw-materials';
  static const String production = '/production';
  static const String warehouse = '/warehouse';
  static const String showroom = '/showroom';
  static const String treasury = '/treasury';
  static const String expenses = '/expenses';
  static const String distributors = '/distributors';
  static const String reports = '/reports';
  static const String sync = '/sync';
  static const String customers = '/customers';
  static const String suppliers = '/suppliers';
  static const String purchases = '/purchases';
  static const String workers = '/workers';
  static const String settings = '/settings';
  static const String audit = '/audit';
  static const String backup = '/backup';
}
