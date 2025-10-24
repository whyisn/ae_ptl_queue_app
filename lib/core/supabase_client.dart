import 'package:supabase_flutter/supabase_flutter.dart';

/// =========================
/// KONFIGURASI SUPABASE APP
/// =========================
/// Ganti nilai konstanta di bawah dengan kredensial milik project Supabase kamu.
/// - kSupabaseUrl   : Project URL (https://<PROJECT-ID>.supabase.co)
/// - kSupabaseAnonKey: Public ANON KEY (Project Settings → API → anon public)
/// - kAuthRedirectUri: Deep link/URL redirect untuk reset password (harus di-whitelist)
///
/// Contoh untuk mobile deep link:
///   kAuthRedirectUri = 'io.supabase.flutter://reset-callback'
///
/// Pastikan juga menambahkan nilai redirect tsb di:
///   Supabase Dashboard → Authentication → URL Configuration → Redirect URLs

/// Supabase config via dart-define (tidak di-hardcode).
/// Set pada perintah `flutter run/build` atau di CI (GitHub/Vercel).
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const String kAuthRedirectUri = '';

/// Alias singkat untuk client
SupabaseClient get supa => Supabase.instance.client;

/// Panggil di main(): await initSupabase();
Future<void> initSupabase() async {
  if (kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty) {
    throw Exception(
      'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
      'Set via --dart-define atau Project Env di CI/hosting.',
    );
  }

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      // redirectTo: kAuthRedirectUri, // siapkan jika pakai deep link
    ),
  );
}

// /// Panggil di main(): await initSupabase();
// Future<void> initSupabase() async {
//   await Supabase.initialize(
//     url: kSupabaseUrl,
//     anonKey: kSupabaseAnonKey,
//     authOptions: const FlutterAuthClientOptions(
//       // Gunakan implicit flow agar nyaman untuk mobile
//       authFlowType: AuthFlowType.implicit,
//       // ignore: deprecated_member_use
//       // redirectTo: kAuthRedirectUri,
//     ),
//   );
// }
