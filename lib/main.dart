import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/splash_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_application_1/features/auth/presentation/pages/update_password_screen.dart';
import 'core/widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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
    if (navigatorKey.currentState == null) {
      // If navigator isn't ready yet, retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), _navigateToUpdatePassword);
      return;
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => const UpdatePasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DilSe',
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
