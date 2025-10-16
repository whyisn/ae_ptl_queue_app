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
const String kSupabaseUrl = 'https://aizrqvfenymowpnibmzi.supabase.co';
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFpenJxdmZlbnltb3dwbmlibXppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0MzAxNzIsImV4cCI6MjA3NjAwNjE3Mn0.IVODfpjF0Q9U6plgILGsLYX2tAX5UmdTg73E4RHE7nc';
const String kAuthRedirectUri = '';

/// Alias singkat untuk client
SupabaseClient get supa => Supabase.instance.client;

/// Panggil di main(): await initSupabase();
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      // Gunakan implicit flow agar nyaman untuk mobile
      authFlowType: AuthFlowType.implicit,
      // ignore: deprecated_member_use
      // redirectTo: kAuthRedirectUri,
    ),
  );
}
