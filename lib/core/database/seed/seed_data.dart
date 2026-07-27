import '../../database/database_helper.dart';
import '../../constants/db_constants.dart';

class SeedData {
  static Future<void> seed(DatabaseHelper dbHelper) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final roles = [
      {'id': 'role_admin', 'name': 'المدير العام'},
      {'id': 'role_production', 'name': 'مدير الإنتاج'},
      {'id': 'role_warehouse', 'name': 'مدير المخزن'},
      {'id': 'role_accountant', 'name': 'المحاسب المالي'},
      {'id': 'role_showroom', 'name': 'مدير المعرض'},
      {'id': 'role_distributor', 'name': 'مسؤول الموزعين'},
      {'id': 'role_materials', 'name': 'مدير المواد الخام'},
    ];

    for (var role in roles) {
      await db.insert(DBConstants.tableRoles, {
        'id': role['id'],
        'role_name': role['name'],
        'description': '',
        'created_at': now,
        'updated_at': now,
      });
    }

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
      'sync_status': 'Pending',
    });

    final settings = {
      'company_name': 'معمل أبو ليث',
      'currency': 'ريال يمني',
      'default_box_size': '60',
      'low_stock_threshold': '100',
    };
    for (var entry in settings.entries) {
      await db.insert(DBConstants.tableSettings, {
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      });
    }
  }
}
