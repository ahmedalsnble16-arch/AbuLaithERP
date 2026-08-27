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
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // أرشفة السجلات قبل الحذف
      final records = await txn.query(
        tableName,
        where: '$dateColumn BETWEEN ? AND ?',
        whereArgs: [fromStr, toStr],
      );

      for (var record in records) {
        await txn.insert(DBConstants.tableSystemArchives, {
          'id': _uuid.v4(),
          'source_table': tableName,
          'source_record_id': record['id']?.toString() ?? _uuid.v4(),
          'archive_data': record.toString(),
          'archive_date': now,
          'archived_by': 'admin',
          'notes': 'حذف حسب فترة من $fromStr إلى $toStr',
          'created_at': now,
        });
      }

      // حذف السجلات
      await txn.delete(
        tableName,
        where: '$dateColumn BETWEEN ? AND ?',
        whereArgs: [fromStr, toStr],
      );

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'مركز إدارة النظام',
        'action': 'حذف حسب فترة',
        'new_data': '$tableName: $fromStr إلى $toStr (${records.length} سجل)',
        'created_at': now,
      });
    });
  }

  /// إلغاء مالي آمن (Void) للجداول المالية
  Future<void> voidFinancialTable({
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
      final records = await txn.query(tableName, where: 'deleted = 0 OR deleted IS NULL');
      int voidCount = 0;

      for (var record in records) {
        final recordId = record['id']?.toString() ?? '';
        final amount = (record['amount'] as num?)?.toDouble() ?? 0;
        final treasuryId = record['treasury_transaction_id']?.toString();

        // أرشفة السجل
        await txn.insert(DBConstants.tableSystemArchives, {
          'id': _uuid.v4(),
          'source_table': tableName,
          'source_record_id': recordId,
          'archive_data': record.toString(),
          'archive_date': now,
          'archived_by': 'admin',
          'notes': notes ?? 'إلغاء مالي آمن لجدول $tableName',
          'created_at': now,
        });

        // إلغاء السجل الأصلي
        await txn.update(
          tableName,
          {
            'deleted': 1,
            'status': DBConstants.statusCancelled,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );

        // إنشاء حركة عكسية في الخزنة
        if (treasuryId != null && amount > 0) {
          // إلغاء حركة الخزنة الأصلية
          await txn.update(
            DBConstants.tableTreasury,
            {
              'deleted': 1,
              'status': DBConstants.statusCancelled,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [treasuryId],
          );

          // إنشاء حركة عكسية
          final originalType = await _getOriginalTransactionType(txn, treasuryId);
          await txn.insert(DBConstants.tableTreasury, {
            'id': _uuid.v4(),
            'transaction_number': 'VOID-${now.millisecondsSinceEpoch}-${recordId.substring(0, Math.min(4, recordId.length))}',
            'transaction_type': originalType == 'صرف' ? 'قبض' : 'صرف',
            'amount': amount,
            'source_module': 'إلغاء - $tableName',
            'source_id': recordId,
            'payment_method': 'نقدي',
            'note': 'حركة عكسية لإلغاء $tableName - $recordId',
            'transaction_date': now.substring(0, 10),
            'status': DBConstants.statusApproved,
            'approved_by': 'admin',
            'created_at': now,
            'updated_at': now,
            'created_by': 'admin',
            'device_id': 'mobile',
            'sync_status': DBConstants.syncPending,
            'deleted': 0,
          });
          voidCount++;
        }
      }

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'مركز إدارة النظام',
        'action': 'إلغاء مالي آمن',
        'new_data': 'إلغاء ${records.length} سجل من $tableName ($voidCount حركة عكسية)',
        'created_at': now,
      });
    });
  }

  /// جلب نوع الحركة الأصلية من الخزنة
  Future<String> _getOriginalTransactionType(dynamic txn, String treasuryId) async {
    final result = await txn.query(
      DBConstants.tableTreasury,
      columns: ['transaction_type'],
      where: 'id = ?',
      whereArgs: [treasuryId],
    );
    if (result.isNotEmpty) {
      return result.first['transaction_type']?.toString() ?? 'صرف';
    }
    return 'صرف';
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

    // التحقق من عدم التكرار
    final existing = await db.query(
      DBConstants.tableDynamicConfigurations,
      where: 'element_name = ? AND element_type = ? AND deleted = 0',
      whereArgs: [elementName, elementType],
    );
    if (existing.isNotEmpty) {
      throw Exception('يوجد عنصر بنفس الاسم والنوع بالفعل');
    }

    await db.transaction((txn) async {
      await txn.insert(DBConstants.tableDynamicConfigurations, {
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
        'sync_status': DBConstants.syncPending,
        'deleted': 0,
      });

      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'مركز إدارة النظام',
        'action': 'إنشاء عنصر ديناميكي',
        'new_data': '$elementType - $elementName (${pageLocation ?? 'غير محدد'})',
        'created_at': now,
      });
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

    // سجل التدقيق
    await db.insert(DBConstants.tableAuditLogs, {
      'id': _uuid.v4(),
      'user_id': 'admin',
      'module': 'مركز إدارة النظام',
      'action': active ? 'إظهار عنصر' : 'إخفاء عنصر',
      'new_data': id,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// حذف عنصر ديناميكي (أرشفة)
  Future<void> deleteElement(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableDynamicConfigurations,
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    // سجل التدقيق
    await db.insert(DBConstants.tableAuditLogs, {
      'id': _uuid.v4(),
      'user_id': 'admin',
      'module': 'مركز إدارة النظام',
      'action': 'حذف عنصر ديناميكي',
      'new_data': id,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// إنشاء نوع جديد في جدول محدد
  Future<void> createNewType({
    required String tableName,
    required String typeName,
  }) async {
    final db = await _dbHelper.database;
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    // التحقق من عدم التكرار
    final existing = await db.query(
      tableName,
      where: 'name = ?',
      whereArgs: [typeName],
    );
    if (existing.isNotEmpty) {
      throw Exception('النوع "$typeName" موجود بالفعل');
    }

    await db.transaction((txn) async {
      if (tableName == DBConstants.tableRepairTypes) {
        await txn.insert(DBConstants.tableRepairTypes, {
          'id': id,
          'name': typeName,
          'created_at': now,
          'updated_at': now,
        });
      } else if (tableName == DBConstants.tableCategories) {
        await txn.insert(DBConstants.tableCategories, {
          'id': id,
          'name': typeName,
          'created_at': now,
          'updated_at': now,
          'sync_status': DBConstants.syncPending,
          'deleted': 0,
        });
      } else {
        throw Exception('الجدول $tableName غير مدعوم للإنشاء المباشر');
      }

      // سجل التدقيق
      await txn.insert(DBConstants.tableAuditLogs, {
        'id': _uuid.v4(),
        'user_id': 'admin',
        'module': 'مركز إدارة النظام',
        'action': 'إنشاء نوع جديد',
        'new_data': '$tableName - $typeName',
        'created_at': now,
      });
    });
  }
}
