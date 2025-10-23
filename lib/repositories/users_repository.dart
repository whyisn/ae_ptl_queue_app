import 'package:supabase_flutter/supabase_flutter.dart';
// import '../core/supabase_client.dart';
import '../models/user_model.dart';

/// UsersRepository: operasi terkait tabel `public.users`
/// - Ambil profil by id
/// - Update profil sendiri (nama/telepon)
/// - (Opsional Admin) set role user
class UsersRepository {
  final SupabaseClient _supa;

  UsersRepository({SupabaseClient? client})
    : _supa = client ?? Supabase.instance.client;

  /// Ambil profil user by id
  Future<AppUser?> getById(String userId) async {
    final row = await _supa
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return AppUser.fromMap(row);
  }

  /// Ambil profil pengguna saat ini
  Future<AppUser?> getCurrent() async {
    final uid = _supa.auth.currentUser?.id;
    if (uid == null) return null;
    return getById(uid);
  }

  /// Update profil diri sendiri (nama & telepon)
  Future<AppUser> updateSelf({String? name, String? phone}) async {
    final uid = _supa.auth.currentUser?.id;
    if (uid == null) {
      throw AuthException('Tidak ada sesi login');
    }
    final row = await _supa
        .from('users')
        .update({
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
        })
        .eq('id', uid)
        .select()
        .single();
    return AppUser.fromMap(row);
  }

  /// (Opsional, ADMIN/PTL saja) Set role user lain
  Future<AppUser> setRole({
    required String userId,
    required UserRole role,
  }) async {
    // Catatan: pastikan policy RLS mengizinkan ADMIN/PTL melakukan ini.
    final row = await _supa
        .from('users')
        .update({'role': roleToString(role)})
        .eq('id', userId)
        .select()
        .single();
    return AppUser.fromMap(row);
  }

  /// Cari user by email (untuk admin tool)
  Future<AppUser?> findByEmail(String email) async {
    final row = await _supa
        .from('users')
        .select()
        .eq('email', email)
        .maybeSingle();
    if (row == null) return null;
    return AppUser.fromMap(row);
  }
}
