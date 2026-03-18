import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:safespace/core/theme/app_colors.dart';
import 'package:safespace/features/auth/presentation/pages/persona_creation_screen.dart';
import 'package:safespace/features/auth/presentation/pages/otp_verification_screen.dart';
import 'package:safespace/features/legal/presentation/pages/terms_screen.dart';
import 'package:safespace/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isTermsAgreed = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _handleSignUp() async {
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
      await _authService.signUp(email: email, password: password);

      if (mounted) {
        if (_authService.isLoggedIn) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PersonaCreationScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(email: email),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Premium Mesh Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  colors: [
                    AppColors.background,
                    Color(0xFF15192D),
                    Color(0xFF0F121F),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          // Accent Glow
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAccent.withValues(alpha: 0.03),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_moon_rounded,
                      size: 72,
                      color: AppColors.primaryAccent,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Join SafeSpace',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your journey to healing starts here',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white38,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 54),

                    // Modern Input Fields
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
                        hintText: 'Create Password',
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
                    const SizedBox(height: 24),
                    
                    // Improved Checkbox Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scale: 1.1,
                          child: Checkbox(
                            value: _isTermsAgreed,
                            activeColor: AppColors.primaryAccent,
                            checkColor: Colors.black,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            onChanged: (val) {
                              setState(() {
                                _isTermsAgreed = val ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TermsScreen()),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                text: "I agree to the ",
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Terms & Privacy Policy",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 42),
                    
                    // Create Account Button
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
                                  if (_isTermsAgreed)
                                    BoxShadow(
                                      color: AppColors.primaryAccent.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: (_isTermsAgreed && !_isLoading) ? _handleSignUp : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryAccent,
                                  foregroundColor: Colors.black87,
                                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                                  disabledForegroundColor: Colors.white24,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 48),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: Colors.white38, fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFF64B5B5),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
