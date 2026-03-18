import 'package:flutter/material.dart';
import 'package:safespace/core/theme/app_colors.dart';
import 'package:safespace/features/home/presentation/pages/main_layout_screen.dart';
import 'package:safespace/features/auth/presentation/pages/signup_screen.dart';
import 'package:safespace/features/legal/presentation/pages/terms_screen.dart';
import 'package:safespace/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Mesh-style background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.background,
                    Color(0xFF101424),
                    Color(0xFF0F121F),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          // Subtle accent glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAccent.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Identity / Logo
                    const Icon(
                      Icons.shield_rounded,
                      size: 80,
                      color: AppColors.primaryAccent,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your safe space',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white38,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 54),

                    // Input Fields
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            color: Colors.white60,
                            size: 22,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1F33),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white60,
                            size: 22,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1F33),
                        contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
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
                          style: TextStyle(
                            color: Colors.white38,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryAccent,
                                strokeWidth: 3,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _handleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryAccent,
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded, size: 22),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 48),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white38, fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUpScreen()),
                            );
                          },
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              color: Color(0xFF64B5B5),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 64),
                    Column(
                      children: [
                        Text(
                          'Your privacy matters. All conversations are anonymous.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.15),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TermsScreen()),
                            );
                          },
                          child: Text(
                            'Terms of Service & Privacy Policy',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
