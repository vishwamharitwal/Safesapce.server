import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dilse/core/theme/app_colors.dart';
import 'package:dilse/features/auth/presentation/pages/persona_creation_screen.dart';
import 'package:dilse/features/auth/presentation/pages/otp_verification_screen.dart';
import 'package:dilse/features/home/presentation/pages/main_layout_screen.dart';
import 'package:dilse/features/legal/presentation/pages/terms_screen.dart';
import 'package:dilse/core/services/auth_service.dart';
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
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus(); // P7: Keyboard dismiss

    // P5: Terms check for email signup too
    if (!_isTermsAgreed) {
      _showError('Please agree to the Terms & Privacy Policy first.');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    // P2: Email format validation
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address (e.g. user@email.com)');
      return;
    }

    // P3: Password minimum length check
    if (password.length < 6) {
      _showError('Password must be at least 6 characters long');
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
    } on SocketException {
      // P8: Network error
      _showError('No internet connection. Please check your network.');
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (!_isTermsAgreed) {
      _showError('Please agree to the Terms & Privacy Policy first.');
      return;
    }

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final response = await _authService.signInWithGoogle();

      if (response == null || response.user == null) {
        return;
      }

      if (mounted && _authService.isLoggedIn) {
        final userId = response.user!.id;

        try {
          final profileResponse = await Supabase.instance.client
              .from('profiles')
              .select('banned_until, nickname, avatar')
              .eq('id', userId)
              .maybeSingle();

          // Ban check
          if (profileResponse != null &&
              profileResponse['banned_until'] != null) {
            final bannedUntil = DateTime.parse(profileResponse['banned_until']);
            if (bannedUntil.isAfter(DateTime.now().toUtc())) {
              await Supabase.instance.client.auth.signOut();
              _showError(
                'Account suspended until ${bannedUntil.toLocal().toString().split(".")[0]}.',
              );
              return;
            }
          }

          // Check nickname — DB trigger auto-creates profile row with null nickname
          // so profileResponse != null does NOT mean user has completed setup
          final dbNickname = profileResponse?['nickname'] as String?;
          final dbAvatar = (profileResponse?['avatar'] as String?) ?? '👤';

          if (dbNickname == null || dbNickname.trim().isEmpty) {
            // New user — needs to create persona
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const PersonaCreationScreen(),
                ),
              );
            }
            return;
          }

          // Existing user with persona — go to main screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MainLayoutScreen(nickname: dbNickname, avatar: dbAvatar),
              ),
            );
          }
        } catch (e) {
          // P4: Profile fetch failed - show error
          _showError('Could not load your profile. Please try again.');
        }
      }
    } on SocketException {
      // P8: Network error
      _showError('No internet connection. Please check your network.');
    } catch (e) {
      _showError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            size: 20,
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
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
                      'Join DilSe',
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
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword, // P6: Toggle support
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Create Password',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white60,
                            size: 22,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white38,
                            size: 22,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1A1F33),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
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
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
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
                                MaterialPageRoute(
                                  builder: (_) => const TermsScreen(),
                                ),
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
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
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
                                      color: AppColors.primaryAccent.withValues(
                                        alpha: 0.15,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: (_isTermsAgreed && !_isLoading)
                                    ? _handleSignUp
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryAccent,
                                  foregroundColor: Colors.black87,
                                  disabledBackgroundColor: Colors.white
                                      .withValues(alpha: 0.05),
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

                    const SizedBox(height: 24),

                    // OR Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Google Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: _isGoogleLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFF1E243D),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isGoogleLoading)
                                    ? null
                                    : _handleGoogleSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Image.asset(
                                        'assets/images/google_logo.png',
                                        height: 20,
                                        width: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 40),

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
                              color: AppColors.primaryAccent,
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
