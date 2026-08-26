import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/dynamic_configuration.dart';

class SystemManagementRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // ========== الإدارة والحذف ==========

  /// جلب قائمة الجداول الموجودة في قاعدة البيانات
  Future<List<String>> getTablesList() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    );
    return result.map((r) => r['name'] as String).toList();
  }

  /// جلب عدد السجلات في جدول محدد
  Future<int> getRecordCount(String tableName) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM "$tableName"');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// تصفير جدول محدد (مع أرشفة قبل التصفير)
  Future<void> clearTable({
    required String tableName,
    required String adminPassword,
    String? notes,
  }) async {
    if (adminPassword != 'admin123') {
      throw Exception('كلمة مرور المدير غير صحيحة');
    }

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // أرشفة البيانات قبل التصفير
      final records = await txn.query(tableName);
      for (var record in records) {
        await txn.insert(DBConstants.tableSystemArchives, {
          'id': _uuid.v4(),
          'source_table': tableName,
          'source_record_id': record['id']?.toString() ?? _uuid.v4(),
          'archive_data': record.toString(),
          'archive_date': now,
          'archived_by': 'admin',
          'notes': notes ?? 'تصفير جدول $tableName',
          'created_at': now,
        });
      }

      // تصفير الجدول
      await txn.delete(tableName);

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'مركز إدارة النظام',
        'action': 'تصفير جدول',
        'new_data': tableName,
        'created_at': now,
      });
    });
  }

  /// حذف سجلات حسب فترة زمنية
  Future<void> deleteRecordsByPeriod({
    required String tableName,
    required String dateColumn,
    required DateTime from,
    required DateTime to,
    required String adminPassword,
  }) async {
    if (adminPassword != 'admin123') {
      throw Exception('كلمة مرور المدير غير صحيحة');
    }

    final db = await _dbHelper.database;
    final fromStr = from.toIso8601String().substring(0, 10);
    final toStr = to.toIso8601String().substring(0, 10);

    await db.delete(
      tableName,
      where: '$dateColumn BETWEEN ? AND ?',
      whereArgs: [fromStr, toStr],
    );
  }

  // ========== الإنشاء والإضافة ==========

  /// حفظ عنصر ديناميكي جديد
  Future<String> createDynamicElement({
    required String elementType,
    required String elementName,
    int displayOrder = 0,
    String? pageLocation,
    String? dataType,
    String? settings,
    String? permissions,
    bool affectsTreasury = false,
  }) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db.insert(DBConstants.tableDynamicConfigurations, {
      'id': id,
      'element_type': elementType,
      'element_name': elementName,
      'display_order': displayOrder,
      'page_location': pageLocation,
      'data_type': dataType,
      'settings': settings,
      'permissions': permissions,
      'affects_treasury': affectsTreasury ? 1 : 0,
      'active': 1,
      'created_at': now,
      'updated_at': now,
      'created_by': 'admin',
      'sync_status': 'Pending',
      'deleted': 0,
    });

    await db.insert(DBConstants.tableAuditLogs, {
      'id': _uuid.v4(),
      'user_id': 'admin',
      'module': 'مركز إدارة النظام',
      'action': 'إنشاء عنصر ديناميكي',
      'new_data': '$elementType - $elementName',
      'created_at': now,
    });

    return id;
  }

  /// جلب جميع العناصر الديناميكية
  Future<List<DynamicConfiguration>> getDynamicElements() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBConstants.tableDynamicConfigurations,
      where: 'deleted = 0',
      orderBy: 'display_order ASC, created_at DESC',
    );
    return maps.map((m) => DynamicConfiguration.fromMap(m)).toList();
  }

  /// إخفاء/إظهار عنصر
  Future<void> toggleElement(String id, bool active) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableDynamicConfigurations,
      {'active': active ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// حذف عنصر ديناميكي
  Future<void> deleteElement(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableDynamicConfigurations,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
