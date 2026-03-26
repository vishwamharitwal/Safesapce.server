import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:safespace/core/theme/app_colors.dart';
import 'package:safespace/features/auth/presentation/pages/login_screen.dart';
import 'package:safespace/features/auth/presentation/pages/persona_creation_screen.dart';
import 'package:safespace/features/home/presentation/pages/main_layout_screen.dart';
import 'package:safespace/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Wait for the animation to finish + a little extra pause (total ~4.5 seconds)
    await Future.delayed(const Duration(milliseconds: 4500));

    if (mounted) {
      final session = Supabase.instance.client.auth.currentSession;
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final bool onboardingShown = prefs.getBool('onboarding_shown') ?? false;

      Widget nextRoute;

      if (session != null) {
        // Check profiles DB (same logic as login_screen) — DB trigger may
        // auto-create a profile row with null nickname for new Google users
        try {
          final profileResponse = await Supabase.instance.client
              .from('profiles')
              .select('nickname, avatar')
              .eq('id', session.user.id)
              .maybeSingle();

          final dbNickname = profileResponse?['nickname'] as String?;

          if (dbNickname != null && dbNickname.trim().isNotEmpty) {
            // Existing user with full profile — go to home
            final dbAvatar = (profileResponse?['avatar'] as String?) ?? '👤';
            nextRoute = MainLayoutScreen(
              nickname: dbNickname,
              avatar: dbAvatar,
            );
          } else {
            // New user or incomplete profile — go to persona creation
            nextRoute = const PersonaCreationScreen();
          }
        } catch (e) {
          final errorStr = e.toString();
          // Invalid/stale session → sign out and go to login
          if (errorStr.contains('user_not_found') ||
              errorStr.contains('User from sub claim') ||
              errorStr.contains('JWT') ||
              errorStr.contains('invalid_token')) {
            debugPrint('SplashScreen: Stale session detected → signing out');
            await Supabase.instance.client.auth.signOut();
            nextRoute = const LoginScreen();
          } else {
            // Other DB error — fallback to persona creation
            nextRoute = const PersonaCreationScreen();
          }
        }
      } else {
        if (!onboardingShown) {
          nextRoute = const OnboardingScreen();
        } else {
          nextRoute = const LoginScreen();
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, _, _) => nextRoute,
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Deep navy
              AppColors.background,
              Color(0xFF0B1120), // Darker shade
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- DILSE LIVE LOGO ---
              SizedBox(
                width: 120, // Reduced from 150
                height: 120, // Reduced from 150
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The Heart Outline
                    const Icon(
                          Icons.favorite_outline_rounded,
                          color: Colors.white,
                          size: 70, // Slightly smaller heart
                        )
                        .animate()
                        .fade(duration: 1000.ms)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutBack,
                        ),

                    // Floating Dots (Rising Upwards)
                    ...List.generate(4, (index) {
                      return Positioned(
                        right: 20 + (index * 6.0),
                        top: 30,
                        child:
                            Container(
                                  width: 5 - (index * 0.8),
                                  height: 5 - (index * 0.8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .fade(
                                  delay: (index * 300).ms,
                                  duration: 1500.ms,
                                  begin: 0.8,
                                  end: 0,
                                )
                                .moveY(
                                  delay: (index * 300).ms,
                                  duration: 1500.ms,
                                  begin: 0,
                                  end: -50,
                                  curve: Curves.easeOut,
                                )
                                .moveX(
                                  delay: (index * 300).ms,
                                  duration: 1500.ms,
                                  begin: 0,
                                  end: 10,
                                  curve: Curves.easeInOutSine,
                                ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 12), // Reduced from 32 (Much tighter)
              // Animated Brand Name
              const Text(
                    'DilSe',
                    style: TextStyle(
                      fontSize: 42, // Balanced from 48
                      fontWeight: FontWeight.w200,
                      letterSpacing: 6, // Slightly tighter
                      color: Colors.white,
                    ),
                  )
                  .animate()
                  .fade(delay: 500.ms, duration: 1200.ms)
                  .shimmer(
                    delay: 1500.ms,
                    duration: 2000.ms,
                    color: Colors.white24,
                  )
                  .callback(
                    delay: 1000.ms,
                    callback: (_) => debugPrint('Logo revealed'),
                  ),

              const SizedBox(height: 6), // Tight gap to subtitle

              Text(
                'FROM THE HEART',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 4,
                ),
              ).animate().fade(delay: 1200.ms, duration: 800.ms),
            ],
          ),
        ),
      ),
    );
  }
}
