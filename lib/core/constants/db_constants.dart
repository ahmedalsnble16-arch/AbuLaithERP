class DBConstants {
  static const String tableUsers = 'users';
  static const String tableRoles = 'roles';
  static const String tablePermissions = 'permissions';
  static const String tableRolePermissions = 'role_permissions';
  static const String tableProducts = 'products';
  static const String tableCategories = 'categories';
  static const String tableRawMaterials = 'raw_materials';
  static const String tableRawStock = 'raw_stock';
  static const String tableStock = 'stock';
  static const String tableStockMovements = 'stock_movements';
  static const String tableRecipes = 'recipes';
  static const String tableProductionPlans = 'production_plans';
  static const String tableProductionBatches = 'production_batches';
  static const String tableProductionCompare = 'production_compare';
  static const String tableShowroomStock = 'showroom_stock';
  static const String tableShowroomMovements = 'showroom_movements';
  static const String tableCustomers = 'customers';
  static const String tableSuppliers = 'suppliers';
  static const String tablePurchases = 'purchases';
  static const String tablePurchaseItems = 'purchase_items';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';
  static const String tableDistributors = 'distributors';
  static const String tableDistributorLoads = 'distributor_loads';
  static const String tableDistributorReturns = 'distributor_returns';
  static const String tableDistributorLoadItems = 'distributor_load_items';
  static const String tableDistributorDamagePrices = 'distributor_damage_prices';
  static const String tableDistributorLoadReturns = 'distributor_load_returns';
  static const String tableDistributorLoadDamage = 'distributor_load_damage';
  static const String tableDailyRemaining = 'daily_remaining';
  static const String tableWorkers = 'workers';
  static const String tableWorkerAccounts = 'worker_accounts';
  static const String tableTreasury = 'treasury';
  static const String tableExpenses = 'expenses';
  static const String tableRevenues = 'revenues';
  static const String tableInventoryCounts = 'inventory_counts';
  static const String tableBackupHistory = 'backup_history';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableErrorLogs = 'error_logs';
  static const String tableSettings = 'settings';
  static const String tableDevices = 'devices';

  static const String syncPending = 'Pending';
  static const String syncSent = 'Sent';
  static const String syncSynced = 'Synced';
  static const String syncFailed = 'Failed';
  static const String syncConflict = 'Conflict';

  static const String statusDraft = 'مسودة';
  static const String statusReview = 'مراجعة';
  static const String statusApproved = 'معتمدة';
  static const String statusRejected = 'مرفوضة';
  static const String statusCancelled = 'ملغاة';

  static const String txnTypeReceipt = 'قبض';
  static const String txnTypePayment = 'صرف';
  static const String txnTypeTransfer = 'تحويل';

  static const String paymentCash = 'نقدي';
  static const String paymentCredit = 'آجل';
}
