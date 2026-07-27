import '../../data/repositories/user_repository.dart';
import 'session_manager.dart';

class AuthService {
  final UserRepository _userRepo = UserRepository();
  final SessionManager _session = SessionManager();

  Future<bool> login(String username, String password) async {
    final user = await _userRepo.login(username, password);
    if (user != null) {
      await _session.init();
      await _session.saveUser(user);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _session.logout();
  }

  bool isLoggedIn() {
    return _session.isLoggedIn();
  }
}
