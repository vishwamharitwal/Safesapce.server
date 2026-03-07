import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_colors.dart';
import 'package:flutter_application_1/features/home/presentation/pages/main_layout_screen.dart';
import 'package:flutter_application_1/features/auth/presentation/pages/signup_screen.dart';
import 'package:flutter_application_1/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _showError('Invalid login credentials, or account does not exist.');
        return;
      }

      if (mounted && _authService.isLoggedIn) {
        final userId = response.user!.id;

        try {
          final profileResponse = await Supabase.instance.client
              .from('profiles')
              .select('banned_until, nickname')
              .eq('id', userId)
              .maybeSingle();

          if (profileResponse == null) {
            await Supabase.instance.client.auth.signOut();
            _showError('No profile found. Please sign up instead.');
            return;
          }

          if (profileResponse['banned_until'] != null) {
            final bannedUntil = DateTime.parse(profileResponse['banned_until']);
            if (bannedUntil.isAfter(DateTime.now())) {
              await Supabase.instance.client.auth.signOut();
              _showError(
                'Account suspended until ${bannedUntil.toLocal().toString().split(".")[0]}.',
              );
              return;
            }
          }

          final metadata = response.user!.userMetadata;
          final nickname =
              (metadata?['nickname'] as String?) ??
              (profileResponse['nickname'] as String?) ??
              'User';
          final avatar = (metadata?['avatar'] as String?) ?? '👤';

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MainLayoutScreen(nickname: nickname, avatar: avatar),
              ),
            );
          }
        } catch (e) {
          // Continue even if profile fetch fails
        }
      }
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        _showError('No account found with this email, or incorrect password.');
      } else {
        _showError(e.message);
      }
    } catch (e) {
      _showError('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address first to reset password.');
      return;
    }

    try {
      await _authService.resetPassword(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email.'),
            backgroundColor: AppColors.primaryAccent,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to send reset link: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your safe space',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 60),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.white54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.white54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryAccent,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Your privacy matters. All conversations are anonymous.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
