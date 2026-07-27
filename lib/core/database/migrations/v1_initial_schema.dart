class V1InitialSchema {
  static const String createUsersTable = '''
    CREATE TABLE IF NOT EXISTS users (
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
      sync_status TEXT DEFAULT 'Pending',
      deleted INTEGER DEFAULT 0,
      FOREIGN KEY (role_id) REFERENCES roles(id)
    )
  ''';

  static const String createRolesTable = '''
    CREATE TABLE IF NOT EXISTS roles (
      id TEXT PRIMARY KEY,
      role_name TEXT NOT NULL UNIQUE,
      description TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      created_by TEXT,
      device_id TEXT,
      sync_status TEXT DEFAULT 'Pending',
      deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createProductsTable = '''
    CREATE TABLE IF NOT EXISTS products (
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
      sync_status TEXT DEFAULT 'Pending',
      deleted INTEGER DEFAULT 0,
      FOREIGN KEY (category_id) REFERENCES categories(id)
    )
  ''';
}
