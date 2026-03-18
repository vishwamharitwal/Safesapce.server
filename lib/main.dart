import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/splash_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:safespace/features/auth/presentation/pages/update_password_screen.dart';
import 'core/widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('SafeSpace .env Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('SafeSpace: Initialization Error caught: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Failed to initialize app correctly.\nPlease check your connection or restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: SafeSpaceApp()));
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
