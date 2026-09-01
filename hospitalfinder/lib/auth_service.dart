// lib/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth (email + password).
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isSignedIn => currentSession != null;

  /// Emits on every sign-in / sign-out / token refresh.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Register a new user. [fullName] is stored in user metadata and copied into
  /// `profiles.full_name` by the `on_auth_user_created` trigger.
  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _supabase.auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _supabase.auth.resetPasswordForEmail(email.trim());
}
