import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Verify OTP for Signup
  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
  }) async {
    return await _supabase.auth.verifyOTP(
      type: OtpType.signup,
      token: token,
      email: email,
    );
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    if (!kIsWeb) {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    }
    await _supabase.auth.signOut();
  }

  // Sign in with Google (google_sign_in v6 — classic SDK, no Credential Manager)
  Future<AuthResponse?> signInWithGoogle() async {
    // Web: use Supabase OAuth flow (redirect-based)
    if (kIsWeb) {
      // For web, we need to redirect back to our local server
      // Get current origin dynamically so it works on any port
      final redirectTo = Uri.base.origin + '/';
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      return null;
    }

    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

    // v6 API: GoogleSignIn constructor (NOT singleton)
    // serverClientId tells Google to issue ID tokens for Supabase backend
    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId.isNotEmpty ? webClientId : null,
      scopes: ['email', 'profile'],
    );

    try {
      // Force account picker by signing out first
      await googleSignIn.signOut();

      // interactive sign-in — returns null if user cancels
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled
      }

      // Get tokens — in v6 both idToken and accessToken are here
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception(
          'Google Sign-In failed: No ID token received.\n'
          'Make sure your GOOGLE_WEB_CLIENT_ID is correct in .env\n'
          'and SHA-1 is registered in Firebase/Google Cloud Console.',
        );
      }

      // Sign in to Supabase with Google tokens
      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on Exception {
      rethrow;
    }
  }

  // Reset Password
  Future<void> resetPassword(
      {required String email, String? redirectTo}) async {
    await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  // Update Password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Check if user is logged in
  bool get isLoggedIn => _supabase.auth.currentUser != null;
}
