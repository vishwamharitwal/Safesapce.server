import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration loader that supports both .env files and --dart-define.
/// 
/// Priority:
/// 1. --dart-define (Compile-time)
/// 2. .env file (Runtime)
class AppConfig {
  AppConfig._();

  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');
  static String get signalingServerUrl => _get('SIGNALING_SERVER_URL');
  static String get googleWebClientId => _get('GOOGLE_WEB_CLIENT_ID');

  static String _get(String key) {
    // Check --dart-define first
    final fromEnv = String.fromEnvironment(key);
    if (fromEnv.isNotEmpty) return fromEnv;
    
    // Check .env file next
    return dotenv.maybeGet(key) ?? '';
  }

  /// Call once at startup to verify all required keys are present.
  static void assertValid() {
    if (supabaseUrl.isEmpty) {
      throw FileSystemException(
        'Missing SUPABASE_URL. Please add it to your .env file or use --dart-define=SUPABASE_URL=...',
        '.env',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw FileSystemException(
        'Missing SUPABASE_ANON_KEY. Please add it to your .env file or use --dart-define=SUPABASE_ANON_KEY=...',
        '.env',
      );
    }
    // Google Client ID and Signaling might be optional depending on your features, 
    // but typically they are required for full app functionality.
  }
}

class FileSystemException implements Exception {
  final String message;
  final String path;
  FileSystemException(this.message, this.path);
  @override
  String toString() => 'FileSystemException: $message ($path)';
}

