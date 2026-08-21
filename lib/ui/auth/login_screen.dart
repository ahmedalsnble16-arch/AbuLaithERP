import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../config/theme.dart';
import '../../core/auth/session_manager.dart';
import '../../core/auth/biometric_auth_service.dart';
import '../../data/repositories/user_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _hasSavedCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _checkSavedCredentials();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _biometricAvailable = canAuthenticate && isDeviceSupported;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _checkSavedCredentials() async {
    final (username, password) = await BiometricAuthService.getLastUser();
    if (mounted) {
      setState(() {
        _hasSavedCredentials = username != null && password != null;
      });
    }
  }

  Future<void> _biometricLogin() async {
    if (!_biometricAvailable) {
      _showError('البصمة غير متوفرة على هذا الجهاز');
      return;
    }

    if (!_hasSavedCredentials) {
      _showError('لا توجد بيانات محفوظة. يرجى تسجيل الدخول بكلمة المرور أولاً.');
      return;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'تسجيل الدخول باستخدام البصمة أو الوجه',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated && mounted) {
        setState(() => _isLoading = true);
        final (username, password) = await BiometricAuthService.getLastUser();
        
        if (username == null || password == null) {
          _showError('لا توجد بيانات محفوظة');
          setState(() => _isLoading = false);
          return;
        }

        final userRepo = UserRepository();
        final user = await userRepo.login(username, password);

        if (user != null) {
          await SessionManager.saveUser(
            id: user.id,
            username: user.username,
            role: user.roleId,
          );
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        } else {
          _showError('فشل تسجيل الدخول بالبصمة - حاول بكلمة المرور');
        }
      }
    } catch (e) {
      _showError('خطأ في البصمة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userRepo = UserRepository();
      final user = await userRepo.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        try {
          await SessionManager.saveUser(
            id: user.id,
            username: user.username,
            role: user.roleId,
          );

          // حفظ بيانات المستخدم للاستخدام المستقبلي مع البصمة
          await BiometricAuthService.saveLastUser(
            _usernameController.text.trim(),
            _passwordController.text.trim(),
          );

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/dashboard');
        } catch (e) {
          if (!mounted) return;
          _showError('خطأ في حفظ الجلسة: $e');
        }
      } else {
        _showError('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.factory, size: 60, color: AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'أبو ليث ERP',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إنتاج الكيك والنواشف',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 40),

                    // زر البصمة (فقط إذا كانت متاحة وتوجد بيانات محفوظة)
                    if (_biometricAvailable && _hasSavedCredentials)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'تسجيل الدخول السريع',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _biometricLogin,
                                  icon: const Icon(Icons.fingerprint, size: 30),
                                  label: const Text('البصمة / الوجه'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 4),
                              const Text('أو تسجيل الدخول بكلمة المرور', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text(
                              'تسجيل الدخول',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _usernameController,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: 'اسم المستخدم',
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('دخول'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('الإصدار 1.0.0', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
