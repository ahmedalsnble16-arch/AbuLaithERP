import 'package:uuid/uuid.dart';
import '../../core/constants/db_constants.dart';
import '../../core/database/database_helper.dart';
import '../models/user.dart';

class UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  // تسجيل الدخول
  Future<User?> login(String username, String password) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBConstants.tableUsers,
      where: 'username = ? AND password_hash = ? AND active = 1 AND deleted = 0',
      whereArgs: [username, password],
    );

    if (maps.isEmpty) return null;

    final user = User.fromMap(maps.first);

    // تحديث آخر تسجيل دخول
    await db.update(
      DBConstants.tableUsers,
      {'last_login': DatabaseHelper.now},
      where: 'id = ?',
      whereArgs: [user.id],
    );

    return user;
  }

  // الحصول على مستخدم بواسطة المعرف
  Future<User?> getUserById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBConstants.tableUsers,
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  // الحصول على جميع المستخدمين
  Future<List<User>> getAllUsers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DBConstants.tableUsers,
      where: 'deleted = 0',
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => User.fromMap(map)).toList();
  }

  // إضافة مستخدم جديد
  Future<String> addUser(User user) async {
    final db = await _dbHelper.database;
    final id = user.id.isNotEmpty ? user.id : _uuid.v4();
    
    await db.insert(DBConstants.tableUsers, user.toMap()..['id'] = id);
    return id;
  }

  // تحديث مستخدم
  Future<void> updateUser(User user) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableUsers,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // حذف منطقي لمستخدم
  Future<void> softDeleteUser(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableUsers,
      {
        'deleted': 1,
        'active': 0,
        'updated_at': DatabaseHelper.now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // تغيير كلمة المرور
  Future<void> changePassword(String userId, String newPassword) async {
    final db = await _dbHelper.database;
    await db.update(
      DBConstants.tableUsers,
      {
        'password_hash': newPassword,
        'updated_at': DatabaseHelper.now,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
