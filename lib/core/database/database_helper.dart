// lib/core/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../config/app_config.dart';
import '../../core/constants/db_constants.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, AppConfig.dbName);

    return await openDatabase(
      path,
      version: AppConfig.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ============ الجداول الأساسية ============
    await db.execute('''
      CREATE TABLE ${DBConstants.tableRoles} (
        id TEXT PRIMARY KEY,
        role_name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableUsers} (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role_id TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        device_id TEXT,
        last_login TEXT,
        active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id_create TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (role_id) REFERENCES ${DBConstants.tableRoles}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tablePermissions} (
        id TEXT PRIMARY KEY,
        permission_name TEXT NOT NULL UNIQUE,
        module TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableRolePermissions} (
        id TEXT PRIMARY KEY,
        role_id TEXT NOT NULL,
        permission_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (role_id) REFERENCES ${DBConstants.tableRoles}(id),
        FOREIGN KEY (permission_id) REFERENCES ${DBConstants.tablePermissions}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableCategories} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableProducts} (
        id TEXT PRIMARY KEY,
        barcode TEXT UNIQUE,
        code TEXT UNIQUE,
        name TEXT NOT NULL,
        category_id TEXT,
        unit TEXT DEFAULT 'قطعة',
        pieces_per_box INTEGER NOT NULL DEFAULT 60,
        wholesale_price REAL NOT NULL DEFAULT 0,
        retail_price REAL NOT NULL DEFAULT 0,
        production_cost REAL NOT NULL DEFAULT 0,
        minimum_stock INTEGER DEFAULT 0,
        image TEXT,
        active INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES ${DBConstants.tableCategories}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableRawMaterials} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        purchase_price REAL DEFAULT 0,
        average_cost REAL DEFAULT 0,
        minimum_qty REAL DEFAULT 0,
        supplier_default TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableRawStock} (
        id TEXT PRIMARY KEY,
        material_id TEXT NOT NULL UNIQUE,
        quantity REAL DEFAULT 0,
        reserved_quantity REAL DEFAULT 0,
        last_inventory_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (material_id) REFERENCES ${DBConstants.tableRawMaterials}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableStock} (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL UNIQUE,
        quantity_pieces INTEGER DEFAULT 0,
        reserved_quantity INTEGER DEFAULT 0,
        average_cost REAL DEFAULT 0,
        last_update TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableStockMovements} (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reference_id TEXT,
        reference_type TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableRecipes} (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        material_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id),
        FOREIGN KEY (material_id) REFERENCES ${DBConstants.tableRawMaterials}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableProductionBatches} (
        id TEXT PRIMARY KEY,
        production_number TEXT NOT NULL UNIQUE,
        product_id TEXT NOT NULL,
        worker_id TEXT,
        shift TEXT,
        production_date TEXT NOT NULL,
        hits INTEGER NOT NULL DEFAULT 0,
        pieces_per_hit INTEGER NOT NULL DEFAULT 0,
        expected_pieces INTEGER NOT NULL DEFAULT 0,
        good_pieces INTEGER NOT NULL DEFAULT 0,
        damaged_pieces INTEGER NOT NULL DEFAULT 0,
        lost_pieces INTEGER NOT NULL DEFAULT 0,
        good_boxes INTEGER NOT NULL DEFAULT 0,
        damaged_boxes INTEGER NOT NULL DEFAULT 0,
        production_cost REAL DEFAULT 0,
        status TEXT DEFAULT '${DBConstants.statusDraft}',
        notes TEXT,
        approved_by TEXT,
        approved_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id),
        FOREIGN KEY (worker_id) REFERENCES ${DBConstants.tableWorkers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableProductionCompare} (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        batch_id TEXT,
        expected_pieces INTEGER DEFAULT 0,
        actual_pieces INTEGER DEFAULT 0,
        difference INTEGER DEFAULT 0,
        loss_percent REAL DEFAULT 0,
        notes TEXT,
        compare_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id),
        FOREIGN KEY (batch_id) REFERENCES ${DBConstants.tableProductionBatches}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableSuppliers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        opening_balance REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        notes TEXT,
        active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tablePurchases} (
        id TEXT PRIMARY KEY,
        supplier_id TEXT NOT NULL,
        invoice_number TEXT NOT NULL,
        total REAL DEFAULT 0,
        paid REAL DEFAULT 0,
        remaining REAL DEFAULT 0,
        payment_type TEXT DEFAULT '${DBConstants.paymentCash}',
        payment_status TEXT DEFAULT 'غير مدفوعة',
        purchase_date TEXT NOT NULL,
        status TEXT DEFAULT '${DBConstants.statusDraft}',
        approved_by TEXT,
        approved_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (supplier_id) REFERENCES ${DBConstants.tableSuppliers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tablePurchaseItems} (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        material_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES ${DBConstants.tablePurchases}(id),
        FOREIGN KEY (material_id) REFERENCES ${DBConstants.tableRawMaterials}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableCustomers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        credit_limit REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableSales} (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL UNIQUE,
        customer_id TEXT,
        customer_name TEXT,
        total REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        grand_total REAL DEFAULT 0,
        payment_type TEXT DEFAULT '${DBConstants.paymentCash}',
        payment_status TEXT DEFAULT 'مدفوعة',
        sale_date TEXT NOT NULL,
        status TEXT DEFAULT '${DBConstants.statusApproved}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES ${DBConstants.tableCustomers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableSaleItems} (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES ${DBConstants.tableSales}(id),
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableShowroomStock} (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL UNIQUE,
        quantity INTEGER DEFAULT 0,
        retail_price REAL DEFAULT 0,
        transfer_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableShowroomMovements} (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        movement_type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        reference_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableDistributors} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        vehicle TEXT,
        address TEXT,
        commission_percent REAL DEFAULT 0,
        commission_value REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableDistributorLoads} (
        id TEXT PRIMARY KEY,
        distributor_id TEXT NOT NULL,
        load_date TEXT NOT NULL,
        status TEXT DEFAULT 'مفتوحة',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableDistributorReturns} (
        id TEXT PRIMARY KEY,
        distributor_id TEXT NOT NULL,
        load_id TEXT,
        product_id TEXT NOT NULL,
        sold INTEGER DEFAULT 0,
        returned INTEGER DEFAULT 0,
        damaged INTEGER DEFAULT 0,
        collected_cash REAL DEFAULT 0,
        commission REAL DEFAULT 0,
        net_amount REAL DEFAULT 0,
        settlement_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id),
        FOREIGN KEY (load_id) REFERENCES ${DBConstants.tableDistributorLoads}(id),
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    // ============ الجداول الجديدة للموزعين ============
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorLoadItems} (
        id TEXT PRIMARY KEY,
        load_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (load_id) REFERENCES ${DBConstants.tableDistributorLoads}(id),
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorDamagePrices} (
        id TEXT PRIMARY KEY,
        distributor_id TEXT NOT NULL,
        damage_type TEXT NOT NULL,
        price_per_piece REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(distributor_id, damage_type),
        FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorLoadReturns} (
        id TEXT PRIMARY KEY,
        distributor_id TEXT NOT NULL,
        load_id TEXT,
        product_id TEXT NOT NULL,
        boxes INTEGER DEFAULT 0,
        pieces INTEGER DEFAULT 0,
        total_pieces INTEGER DEFAULT 0,
        unit_price REAL DEFAULT 0,
        total_value REAL DEFAULT 0,
        return_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT 'Pending',
        FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id),
        FOREIGN KEY (load_id) REFERENCES ${DBConstants.tableDistributorLoads}(id),
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorLoadDamage} (
        id TEXT PRIMARY KEY,
        distributor_id TEXT NOT NULL,
        load_id TEXT,
        damage_type TEXT NOT NULL,
        pieces INTEGER DEFAULT 0,
        price_per_piece REAL DEFAULT 0,
        total_value REAL DEFAULT 0,
        damage_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT 'Pending',
        FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id),
        FOREIGN KEY (load_id) REFERENCES ${DBConstants.tableDistributorLoads}(id)
      )
    ''');

    // ============ جداول المعرض الجديدة ============
    await db.execute('''
      CREATE TABLE IF NOT EXISTS showroom_daily_entries (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL,
        product_id TEXT NOT NULL,
        load_boxes INTEGER DEFAULT 0,
        load_pieces INTEGER DEFAULT 0,
        load_total_pieces INTEGER DEFAULT 0,
        return_boxes INTEGER DEFAULT 0,
        return_pieces INTEGER DEFAULT 0,
        return_total_pieces INTEGER DEFAULT 0,
        load_value REAL DEFAULT 0,
        return_value REAL DEFAULT 0,
        net_value REAL DEFAULT 0,
        remaining_boxes INTEGER DEFAULT 0,
        remaining_pieces INTEGER DEFAULT 0,
        remaining_value REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS showroom_daily_account (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL UNIQUE,
        previous_remaining_value REAL DEFAULT 0,
        total_load_value REAL DEFAULT 0,
        total_return_value REAL DEFAULT 0,
        net_goods_value REAL DEFAULT 0,
        total_worker_expenses REAL DEFAULT 0,
        total_worker_advances REAL DEFAULT 0,
        total_daily_expenses REAL DEFAULT 0,
        other_income REAL DEFAULT 0,
        showroom_expense REAL DEFAULT 0,
        total_due REAL DEFAULT 0,
        cash_received REAL DEFAULT 0,
        cash_confirmed INTEGER DEFAULT 0,
        confirmed_by TEXT,
        result_amount REAL DEFAULT 0,
        result_status TEXT,
        closed INTEGER DEFAULT 0,
        closed_by TEXT,
        closed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS showroom_daily_expenses (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL,
        amount REAL NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        FOREIGN KEY (business_date) REFERENCES showroom_daily_account(business_date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS showroom_khat (
        id TEXT PRIMARY KEY,
        business_date TEXT NOT NULL,
        worker_name TEXT NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT
      )
    ''');

    // ============ جدول المتبقي اليومي ============
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DBConstants.tableDailyRemaining} (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        remaining_date TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        boxes INTEGER DEFAULT 0,
        pieces INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        UNIQUE(product_id, remaining_date),
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
      )
    ''');

    // ============ جدول العمال (مُحدث) ============
    await db.execute('''
      CREATE TABLE ${DBConstants.tableWorkers} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        job TEXT,
        phone TEXT,
        salary REAL DEFAULT 0,
        daily_salary REAL DEFAULT 0,
        daily_expense REAL DEFAULT 0,
        card_number TEXT,
        card_image TEXT,
        hire_date TEXT,
        active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    // ============ جداول العمال الجديدة (الحضور والمصاريف اليومية) ============
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worker_attendance (
        id TEXT PRIMARY KEY,
        worker_id TEXT NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(worker_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS worker_daily_expenses (
        id TEXT PRIMARY KEY,
        worker_id TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL DEFAULT 0,
        details TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableWorkerAccounts} (
        id TEXT PRIMARY KEY,
        worker_id TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        FOREIGN KEY (worker_id) REFERENCES ${DBConstants.tableWorkers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableTreasury} (
        id TEXT PRIMARY KEY,
        transaction_number TEXT NOT NULL UNIQUE,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        source_module TEXT,
        source_id TEXT,
        payment_method TEXT DEFAULT 'نقدي',
        note TEXT,
        transaction_date TEXT NOT NULL,
        status TEXT DEFAULT '${DBConstants.statusApproved}',
        approved_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableExpenses} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT,
        amount REAL NOT NULL,
        note TEXT,
        expense_date TEXT NOT NULL,
        status TEXT DEFAULT '${DBConstants.statusApproved}',
        approved_by TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableRevenues} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT,
        amount REAL NOT NULL,
        source TEXT,
        note TEXT,
        revenue_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableInventoryCounts} (
        id TEXT PRIMARY KEY,
        product_id TEXT,
        material_id TEXT,
        system_quantity REAL DEFAULT 0,
        actual_quantity REAL DEFAULT 0,
        difference REAL DEFAULT 0,
        status TEXT DEFAULT '${DBConstants.statusDraft}',
        counted_by TEXT,
        approved_by TEXT,
        count_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        device_id TEXT,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id),
        FOREIGN KEY (material_id) REFERENCES ${DBConstants.tableRawMaterials}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableSyncQueue} (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        sync_status TEXT DEFAULT '${DBConstants.syncPending}',
        retries INTEGER DEFAULT 0,
        error_message TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableAuditLogs} (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        module TEXT NOT NULL,
        action TEXT NOT NULL,
        old_data TEXT,
        new_data TEXT,
        device_id TEXT,
        ip_address TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${DBConstants.tableUsers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableErrorLogs} (
        id TEXT PRIMARY KEY,
        error_type TEXT NOT NULL,
        error_message TEXT NOT NULL,
        stack_trace TEXT,
        device_id TEXT,
        app_version TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableBackupHistory} (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        file_size INTEGER,
        backup_type TEXT DEFAULT 'يدوي',
        created_by TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableDevices} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        device_name TEXT,
        device_type TEXT,
        device_token TEXT,
        last_sync TEXT,
        active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${DBConstants.tableUsers}(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DBConstants.tableSettings} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // إدراج البيانات الأولية
    await _seedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorLoadItems} (
          id TEXT PRIMARY KEY,
          load_id TEXT NOT NULL,
          product_id TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (load_id) REFERENCES ${DBConstants.tableDistributorLoads}(id),
          FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorDamagePrices} (
          id TEXT PRIMARY KEY,
          distributor_id TEXT NOT NULL,
          damage_type TEXT NOT NULL,
          price_per_piece REAL NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(distributor_id, damage_type),
          FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorLoadReturns} (
          id TEXT PRIMARY KEY,
          distributor_id TEXT NOT NULL,
          load_id TEXT,
          product_id TEXT NOT NULL,
          boxes INTEGER DEFAULT 0,
          pieces INTEGER DEFAULT 0,
          total_pieces INTEGER DEFAULT 0,
          unit_price REAL DEFAULT 0,
          total_value REAL DEFAULT 0,
          return_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          created_by TEXT,
          device_id TEXT,
          sync_status TEXT DEFAULT 'Pending',
          FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id),
          FOREIGN KEY (load_id) REFERENCES ${DBConstants.tableDistributorLoads}(id),
          FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DBConstants.tableDistributorLoadDamage} (
          id TEXT PRIMARY KEY,
          distributor_id TEXT NOT NULL,
          load_id TEXT,
          damage_type TEXT NOT NULL,
          pieces INTEGER DEFAULT 0,
          price_per_piece REAL DEFAULT 0,
          total_value REAL DEFAULT 0,
          damage_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          created_by TEXT,
          device_id TEXT,
          sync_status TEXT DEFAULT 'Pending',
          FOREIGN KEY (distributor_id) REFERENCES ${DBConstants.tableDistributors}(id),
          FOREIGN KEY (load_id) REFERENCES ${DBConstants.tableDistributorLoads}(id)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DBConstants.tableDailyRemaining} (
          id TEXT PRIMARY KEY,
          product_id TEXT NOT NULL,
          remaining_date TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 0,
          boxes INTEGER DEFAULT 0,
          pieces INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          created_by TEXT,
          device_id TEXT,
          UNIQUE(product_id, remaining_date),
          FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS showroom_daily_entries (
          id TEXT PRIMARY KEY,
          business_date TEXT NOT NULL,
          product_id TEXT NOT NULL,
          load_boxes INTEGER DEFAULT 0,
          load_pieces INTEGER DEFAULT 0,
          load_total_pieces INTEGER DEFAULT 0,
          return_boxes INTEGER DEFAULT 0,
          return_pieces INTEGER DEFAULT 0,
          return_total_pieces INTEGER DEFAULT 0,
          load_value REAL DEFAULT 0,
          return_value REAL DEFAULT 0,
          net_value REAL DEFAULT 0,
          remaining_boxes INTEGER DEFAULT 0,
          remaining_pieces INTEGER DEFAULT 0,
          remaining_value REAL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (product_id) REFERENCES ${DBConstants.tableProducts}(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS showroom_daily_account (
          id TEXT PRIMARY KEY,
          business_date TEXT NOT NULL UNIQUE,
          previous_remaining_value REAL DEFAULT 0,
          total_load_value REAL DEFAULT 0,
          total_return_value REAL DEFAULT 0,
          net_goods_value REAL DEFAULT 0,
          total_worker_expenses REAL DEFAULT 0,
          total_worker_advances REAL DEFAULT 0,
          total_daily_expenses REAL DEFAULT 0,
          other_income REAL DEFAULT 0,
          showroom_expense REAL DEFAULT 0,
          total_due REAL DEFAULT 0,
          cash_received REAL DEFAULT 0,
          cash_confirmed INTEGER DEFAULT 0,
          confirmed_by TEXT,
          result_amount REAL DEFAULT 0,
          result_status TEXT,
          closed INTEGER DEFAULT 0,
          closed_by TEXT,
          closed_at TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS showroom_daily_expenses (
          id TEXT PRIMARY KEY,
          business_date TEXT NOT NULL,
          amount REAL NOT NULL,
          details TEXT,
          created_at TEXT NOT NULL,
          created_by TEXT,
          device_id TEXT,
          FOREIGN KEY (business_date) REFERENCES showroom_daily_account(business_date)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS showroom_khat (
          id TEXT PRIMARY KEY,
          business_date TEXT NOT NULL,
          worker_name TEXT NOT NULL,
          amount REAL NOT NULL,
          created_at TEXT NOT NULL,
          created_by TEXT,
          device_id TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        ALTER TABLE ${DBConstants.tableWorkers} ADD COLUMN daily_salary REAL DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE ${DBConstants.tableWorkers} ADD COLUMN daily_expense REAL DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE ${DBConstants.tableWorkers} ADD COLUMN card_number TEXT
      ''');
      await db.execute('''
        ALTER TABLE ${DBConstants.tableWorkers} ADD COLUMN card_image TEXT
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS worker_attendance (
          id TEXT PRIMARY KEY,
          worker_id TEXT NOT NULL,
          date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          UNIQUE(worker_id, date)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS worker_daily_expenses (
          id TEXT PRIMARY KEY,
          worker_id TEXT NOT NULL,
          date TEXT NOT NULL,
          amount REAL DEFAULT 0,
          details TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    await db.insert(DBConstants.tableRoles, {
      'id': 'role_admin',
      'role_name': 'المدير العام',
      'description': 'يمتلك جميع الصلاحيات',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert(DBConstants.tableRoles, {
      'id': 'role_production',
      'role_name': 'مدير الإنتاج',
      'description': 'مسؤول عن الإنتاج فقط',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert(DBConstants.tableRoles, {
      'id': 'role_warehouse',
      'role_name': 'مدير المخزن',
      'description': 'مسؤول عن المخازن',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert(DBConstants.tableRoles, {
      'id': 'role_accountant',
      'role_name': 'المحاسب المالي',
      'description': 'مسؤول عن الحسابات والخزنة',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert(DBConstants.tableRoles, {
      'id': 'role_showroom',
      'role_name': 'مدير المعرض',
      'description': 'مسؤول عن المعرض والمبيعات',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert(DBConstants.tableRoles, {
      'id': 'role_distributor',
      'role_name': 'مسؤول الموزعين',
      'description': 'مسؤول عن تحميل وتصفية الموزعين',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert(DBConstants.tableRoles, {
      'id': 'role_materials',
      'role_name': 'مدير المواد الخام',
      'description': 'مسؤول عن المواد الخام والمشتريات',
      'created_at': now,
      'updated_at': now,
    });

    await db.insert(DBConstants.tableUsers, {
      'id': 'user_admin_001',
      'full_name': 'مدير النظام',
      'username': 'admin',
      'password_hash': 'admin123',
      'role_id': 'role_admin',
      'phone': '770000000',
      'active': 1,
      'created_at': now,
      'updated_at': now,
      'sync_status': DBConstants.syncPending,
    });

    final defaultSettings = {
      'company_name': 'معمل أبو ليث',
      'company_activity': 'إنتاج الكيك والنواشف',
      'currency': 'ريال يمني',
      'default_box_size': '60',
      'low_stock_threshold': '100',
      'session_timeout': '30',
      'app_version': '1.0.0',
    };

    for (var entry in defaultSettings.entries) {
      await db.insert(DBConstants.tableSettings, {
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      });
    }
  }

  static String get now => DateTime.now().toIso8601String();
}
