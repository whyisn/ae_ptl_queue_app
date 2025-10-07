import 'package:supabase_flutter/supabase_flutter.dart';
// import '../core/supabase_client.dart';
import '../models/user_model.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  /// Login email/password
  Future<AppUser> signIn(String email, String password) async {
    final res = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) {
      throw Exception('Login gagal');
    }

    // Pastikan record di tabel users ada
    await supabase.rpc('ensure_user', params: {'p_name': email});

    // Ambil profil
    final row =
        await supabase
            .from('users')
            .select()
            .eq('id', res.user!.id)
            .maybeSingle();

    if (row == null) throw Exception('User profile tidak ditemukan');
    return AppUser.fromMap(row);
  }

  /// Registrasi user AE baru
  Future<AppUser> signUp(String email, String password, {String? name}) async {
    final res = await supabase.auth.signUp(email: email, password: password);
    if (res.user == null) {
      throw Exception('Registrasi gagal');
    }

    await supabase.rpc('ensure_user', params: {'p_name': name ?? email});

    final row =
        await supabase
            .from('users')
            .select()
            .eq('id', res.user!.id)
            .maybeSingle();
    if (row == null) throw Exception('User profile tidak ditemukan');
    return AppUser.fromMap(row);
  }

  /// Logout
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  /// Ambil user saat ini
  Future<AppUser?> currentUser() async {
    final u = supabase.auth.currentUser;
    if (u == null) return null;
    final row =
        await supabase.from('users').select().eq('id', u.id).maybeSingle();
    return row == null ? null : AppUser.fromMap(row);
  }
}
