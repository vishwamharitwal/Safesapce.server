import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/splash_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:safespace/features/auth/presentation/pages/update_password_screen.dart';
import 'core/widgets/offline_banner.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── Global Flutter framework error handler ──────────────────────────
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details); // keeps red-screen in debug
        debugPrint('🔴 FlutterError: ${details.exception}\n${details.stack}');
      };

      // ── Global platform / async error handler ──────────────────────────
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('🔴 PlatformDispatcher error: $error\n$stack');
        return true; // mark as handled
      };

      // ── Config and Initialization ─────────────────────────────────────────
      try {
        AppConfig.assertValid();
        
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );

        runApp(const ProviderScope(child: SafeSpaceApp()));
      } catch (e, stack) {
        debugPrint(' SafeSpace: Initialization error: $e\n$stack');
        
        runApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Initialization Error',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // Try to restart if possible, or just stay here
                        },
                        child: const Text('Check instructions and restart'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    },
    // ── Zone-level catch-all (async errors not caught above) ───────────
    (Object error, StackTrace stack) {
      debugPrint('🔴 Unhandled zone error: $error\n$stack');
    },
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SafeSpaceApp extends StatefulWidget {
  const SafeSpaceApp({super.key});

  @override
  State<SafeSpaceApp> createState() => _SafeSpaceAppState();
}

class _SafeSpaceAppState extends State<SafeSpaceApp> {
  StreamSubscription? _authSubscription;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    // 1. Supabase Auth Listener (Handles recovery event after redirection)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Supabase: Password Recovery event detected');
        _navigateToUpdatePassword();
      }
    });

    // 2. AppLinks Listener (Handles the incoming deep link URL)
    final appLinks = AppLinks();
    
    // Check initial link (if app was closed)
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Listen for incoming links while app is in foreground/background
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('SafeSpace: Deep Link received: $uri');
    // Check for our reset callback scheme or supabase recovery type
    if (uri.toString().contains('reset-callback') || uri.toString().contains('type=recovery')) {
      _navigateToUpdatePassword();
    }
  }

  void _navigateToUpdatePassword() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => const UpdatePasswordScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSpace',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        return OfflineBanner(child: child!);
      },
      home: const SplashScreen(),
    );
  }
}
