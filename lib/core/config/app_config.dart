/// Compile-time configuration via --dart-define.
///
/// Usage (dev):
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ... \
///     --dart-define=SIGNALING_SERVER_URL=https://... \
///     --dart-define=GOOGLE_WEB_CLIENT_ID=126...apps.googleusercontent.com
///
/// Usage (CI / release build):
///   flutter build apk \
///     --dart-define=SUPABASE_URL=$SUPABASE_URL \
///     ...
///
/// SECURITY: Never put real secrets in this file. Defaults are empty so that
/// a missing define causes a clear runtime failure instead of silently using
/// hardcoded credentials.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String signalingServerUrl = String.fromEnvironment(
    'SIGNALING_SERVER_URL',
    defaultValue: '',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Call once at startup to verify all required keys are present.
  /// NOTE: assert() is stripped in release builds. Use a runtime check
  /// or flutter_dotenv for production validation.
  static void assertValid() {
    assert(
      supabaseUrl.isNotEmpty,
      'Missing SUPABASE_URL. Use --dart-define=SUPABASE_URL=https://xxx.supabase.co',
    );
    assert(
      supabaseAnonKey.isNotEmpty,
      'Missing SUPABASE_ANON_KEY. Use --dart-define=SUPABASE_ANON_KEY=eyJ...',
    );
    assert(
      signalingServerUrl.isNotEmpty,
      'Missing SIGNALING_SERVER_URL. Use --dart-define=SIGNALING_SERVER_URL=https://...',
    );
    assert(
      googleWebClientId.isNotEmpty,
      'Missing GOOGLE_WEB_CLIENT_ID. Use --dart-define=GOOGLE_WEB_CLIENT_ID=126...',
    );
  }
}
