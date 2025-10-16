import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/media_model.dart';
import '../repositories/requests_repository.dart';

/// Controller untuk media per request:
/// - fetch daftar media (dengan signed URL dari MediaService)
/// - upload media baru
/// - hapus media
class MediaController extends ChangeNotifier {
  final RequestsRepository _repo;

  MediaController(this._repo);

  // Map requestId -> daftar media
  final Map<String, List<MediaModel>> _mediaByRequest = {};
  final Map<String, bool> _loadingByRequest = {};
  final Map<String, String?> _errorByRequest = {};

  List<MediaModel> getMedia(String requestId) =>
      _mediaByRequest[requestId] ?? const [];

  bool isLoading(String requestId) => _loadingByRequest[requestId] ?? false;

  // ===== Aliases agar kompatibel dengan pemanggilan yang sudah ada di pages =====
  List<MediaModel> mediaOf(String requestId) => getMedia(requestId);
  bool loadingOf(String requestId) => isLoading(requestId);
  Future<void> loadMedia(String requestId) => load(requestId);
  Future<void> delete(String requestId, MediaModel media) =>
      remove(requestId, media);

  String? getError(String requestId) => _errorByRequest[requestId];

  /// Ambil media untuk satu request (signed URL dihasilkan oleh MediaService)
  Future<void> load(String requestId) async {
    _loadingByRequest[requestId] = true;
    notifyListeners();
    try {
      final media = await _repo.fetchMedia(requestId);
      _mediaByRequest[requestId] = media;
      _errorByRequest[requestId] = null;
    } catch (e) {
      _errorByRequest[requestId] = e.toString();
    } finally {
      _loadingByRequest[requestId] = false;
      notifyListeners();
    }
  }

  /// Upload satu file; setelah selesai, otomatis refresh daftar.
  Future<void> upload(String requestId, File file) async {
    _loadingByRequest[requestId] = true;
    notifyListeners();
    try {
      final m = await _repo.uploadMedia(requestId: requestId, file: file);
      final list = List<MediaModel>.from(_mediaByRequest[requestId] ?? []);
      list.add(m);
      _mediaByRequest[requestId] = list;
      _errorByRequest[requestId] = null;

      // (Opsional) bisa juga panggil load(requestId) kalau ingin re-generate signed URL
      // await load(requestId);
    } catch (e) {
      _errorByRequest[requestId] = e.toString();
    } finally {
      _loadingByRequest[requestId] = false;
      notifyListeners();
    }
  }

  /// Hapus satu media; setelah selesai, keluarkan dari cache lokal.
  Future<void> remove(String requestId, MediaModel media) async {
    _loadingByRequest[requestId] = true;
    notifyListeners();
    try {
      await _repo.deleteMedia(media);
      final list = List<MediaModel>.from(_mediaByRequest[requestId] ?? []);
      list.removeWhere((e) => e.id == media.id);
      _mediaByRequest[requestId] = list;
      _errorByRequest[requestId] = null;
    } catch (e) {
      _errorByRequest[requestId] = e.toString();
    } finally {
      _loadingByRequest[requestId] = false;
      notifyListeners();
    }
  }
}
