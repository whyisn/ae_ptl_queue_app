import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/media_model.dart';

/// Service untuk bucket `request-media` + tabel `request_media`.
class MediaService {
  final supabase = Supabase.instance.client;

  static const String bucket = 'request-media';

  /// Upload satu file.
  /// Object path: `request/<requestId>/<timestamp>_<filename>`
  Future<MediaModel> uploadMedia({
    required String requestId,
    required File file,
    required MediaType type,
    String? caption,
  }) async {
    final base = p.basename(file.path);
    final filename = '${DateTime.now().millisecondsSinceEpoch}_$base';
    final objectPath = 'request/$requestId/$filename';

    await supabase.storage.from(bucket).upload(objectPath, file);

    final row = await supabase
        .from('request_media')
        .insert({
          'request_id': requestId,
          'url': objectPath, // simpan path objek, bukan public URL
          'type': mediaTypeToString(type),
          'caption': caption,
        })
        .select()
        .single();

    return MediaModel.fromMap(row);
  }

  /// Ambil semua media milik request + buat signed URL (1 jam).
  Future<List<MediaModel>> fetchMedia(String requestId) async {
    final rows = await supabase
        .from('request_media')
        .select()
        .eq('request_id', requestId);

    final List<MediaModel> media = [];
    for (final m in rows) {
      final path = (m['url'] as String?) ?? '';
      String? signed;
      if (path.isNotEmpty) {
        signed = await supabase.storage
            .from(bucket)
            .createSignedUrl(path, 3600);
      }
      media.add(MediaModel.fromMap({...m, 'signed_url': signed}));
    }
    return media;
  }

  /// Hapus media (row di DB lebih dulu agar aman RLS) + object di storage.
  Future<void> deleteMedia(MediaModel media) async {
    await supabase.from('request_media').delete().eq('id', media.id);
    if (media.path.isNotEmpty) {
      await supabase.storage.from(bucket).remove([media.path]);
    }
  }
}
