import '../../data/repositories/user_repository.dart';
import 'session_manager.dart';

class AuthService {
  final UserRepository _userRepo = UserRepository();

  Future<bool> login(String username, String password) async {
    final user = await _userRepo.login(username, password);
    if (user != null) {
      await SessionManager.saveUser(
        id: user.id,
        username: user.username,
        role: user.roleId,
      );
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await SessionManager.logout();
  }

  Future<bool> isLoggedIn() async {
    return await SessionManager.isLoggedIn();
  }
}
