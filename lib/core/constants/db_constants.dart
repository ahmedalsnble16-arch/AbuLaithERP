class DBConstants {
  // ========== الجداول الأساسية ==========
  static const String tableUsers = 'users';
  static const String tableRoles = 'roles';
  static const String tablePermissions = 'permissions';
  static const String tableRolePermissions = 'role_permissions';
  static const String tableCategories = 'categories';
  static const String tableProducts = 'products';
  static const String tableRawMaterials = 'raw_materials';
  static const String tableRawStock = 'raw_stock';
  static const String tableStock = 'stock';
  static const String tableStockMovements = 'stock_movements';
  static const String tableRecipes = 'recipes';
  static const String tableProductionPlans = 'production_plans';
  static const String tableProductionBatches = 'production_batches';
  static const String tableProductionCompare = 'production_compare';
  static const String tableSuppliers = 'suppliers';
  static const String tablePurchases = 'purchases';
  static const String tablePurchaseItems = 'purchase_items';
  static const String tableCustomers = 'customers';
  static const String tableSales = 'sales';
  static const String tableSaleItems = 'sale_items';

  // ========== الموزعين ==========
  static const String tableDistributors = 'distributors';
  static const String tableDistributorLoads = 'distributor_loads';
  static const String tableDistributorLoadItems = 'distributor_load_items';
  static const String tableDistributorReturns = 'distributor_returns';
  static const String tableDistributorDamagePrices = 'distributor_damage_prices';
  static const String tableDistributorLoadReturns = 'distributor_load_returns';
  static const String tableDistributorLoadDamage = 'distributor_load_damage';
  static const String tableDistributorProductPrices = 'distributor_product_prices';

  // ========== المعرض ==========
  static const String tableShowroomStock = 'showroom_stock';
  static const String tableShowroomMovements = 'showroom_movements';
  static const String tableShowroomDailyEntries = 'showroom_daily_entries';
  static const String tableShowroomDailyAccount = 'showroom_daily_account';
  static const String tableShowroomDailyExpenses = 'showroom_daily_expenses';
  static const String tableShowroomKhat = 'showroom_khat';

  // ========== العمال ==========
  static const String tableWorkers = 'workers';
  static const String tableWorkerAccounts = 'worker_accounts';
  static const String tableWorkerAttendance = 'worker_attendance';
  static const String tableWorkerDailyExpenses = 'worker_daily_expenses';

  // ========== الإدارة المالية ==========
  static const String tableTreasury = 'treasury';
  static const String tableExpenses = 'expenses';
  static const String tableRevenues = 'revenues';

  // ========== الشركاء المالكين ==========
  static const String tablePartners = 'partners';
  static const String tablePartnerTransactions = 'partner_transactions';

  // ========== الجرد والمخزون ==========
  static const String tableInventoryCounts = 'inventory_counts';
  static const String tableDailyRemaining = 'daily_remaining';

  // ========== النظام ==========
  static const String tableSyncQueue = 'sync_queue';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableErrorLogs = 'error_logs';
  static const String tableBackupHistory = 'backup_history';
  static const String tableSettings = 'settings';
  static const String tableDevices = 'devices';

  // ========== أنواع حركات الشركاء ==========
  static const String partnerTxnSalary = 'راتب';
  static const String partnerTxnWithdrawal = 'سحب';
  static const String partnerTxnAdvance = 'براني';
  static const String partnerTxnExpense = 'مصروف شخصي';
  static const String partnerTxnLoan = 'سلفة';
  static const String partnerTxnSettlement = 'تسوية';
  static const String partnerTxnDeposit = 'إيداع';
  static const String partnerTxnProfit = 'أرباح مستحقة';
  static const String partnerTxnProfitPaid = 'أرباح مصروفة';

  // ========== الثوابت ==========
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
