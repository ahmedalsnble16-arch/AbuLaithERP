import '../models/user.dart';
import '../repositories/user_repository.dart';

class UserService {
  final UserRepository _repository = UserRepository();

  Future<User?> login(String username, String password) async {
    return await _repository.login(username, password);
  }

  Future<User?> getUserById(String id) async {
    return await _repository.getUserById(id);
  }

  Future<List<User>> getAllUsers() async {
    return await _repository.getAllUsers();
  }

  Future<String> addUser(User user) async {
    return await _repository.addUser(user);
  }

  Future<void> updateUser(User user) async {
    await _repository.updateUser(user);
  }

  Future<void> deleteUser(String id) async {
    await _repository.softDeleteUser(id);
  }

  Future<void> changePassword(String userId, String newPassword) async {
    await _repository.changePassword(userId, newPassword);
  }
}
