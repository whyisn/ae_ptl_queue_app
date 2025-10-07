import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final AuthService _svc;

  const AuthRepository(this._svc);

  /// Login → kembalikan AppUser
  Future<AppUser> signIn(String email, String password) {
    return _svc.signIn(email, password);
  }

  /// Register AE baru → kembalikan AppUser
  Future<AppUser> signUp(String email, String password, {String? name}) {
    return _svc.signUp(email, password, name: name);
  }

  /// Logout
  Future<void> signOut() => _svc.signOut();

  /// AppUser saat ini (null jika tidak login)
  Future<AppUser?> currentUser() => _svc.currentUser();

  /// Supabase User (mentah)
  User? get supabaseUser => _svc.supabase.auth.currentUser;

  /// Stream perubahan auth (signedIn, signedOut, userUpdated)
  Stream<AuthState> onAuthStateChange() => _svc.supabase.auth.onAuthStateChange;
}
