import 'package:supabase_flutter/supabase_flutter.dart';
// import '../core/supabase_client.dart';

/// SchedulerService hanya memanggil RPC yang sudah dibuat di Supabase.
/// Misalnya purge otomatis, atau auto-release review.
class SchedulerService {
  final supabase = Supabase.instance.client;

  /// Panggil purge old closed requests (dijalankan manual jika perlu)
  Future<void> purgeOldClosed() async {
    await supabase.rpc('purge_old_closed');
  }

  /// Panggil auto_release_reviews (jika diaktifkan)
  Future<void> releaseStuckReviews() async {
    await supabase.rpc('auto_release_reviews');
  }
}
