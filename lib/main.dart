import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/splash_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:dilse/features/auth/presentation/pages/update_password_screen.dart';
import 'core/widgets/offline_banner.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── Global Flutter framework error handler ──────────────────────────
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details); // keeps red-screen in debug
      };

      // ── Global platform / async error handler ──────────────────────────
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        return true; // mark as handled
      };

      // ── Config and Initialization ─────────────────────────────────────────
      try {
        // Load .env file first
        await dotenv.load(fileName: ".env");
        
        AppConfig.assertValid();
        
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
          // Tells Supabase to handle deep links with this host as auth callbacks
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );

        runApp(const ProviderScope(child: SafeSpaceApp()));
      } catch (e) {
        
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

  Future<void> _handleDeepLink(Uri uri) async {
    final uriStr = uri.toString();
    // Only handle our reset-callback deep links
    if (uriStr.contains('reset-callback') || uriStr.contains('type=recovery')) {
      try {
        // 🔑 CRITICAL: Pass URI to Supabase so it can extract the
        // access_token + refresh_token from the URL fragment.
        // This triggers the passwordRecovery auth event which then
        // calls _navigateToUpdatePassword via the auth listener.
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        // If token parsing fails, session is invalid — go back to login
        debugPrint('[DeepLink] getSessionFromUrl error: $e');
        _navigateToUpdatePassword(); // Still try to show the screen
      }
    }
  }

  void _navigateToUpdatePassword() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState?.mounted == true) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const UpdatePasswordScreen(),
          ),
          (route) => route.isFirst, // Keep splash/home as base
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
