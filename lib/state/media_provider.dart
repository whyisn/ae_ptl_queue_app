import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/media_model.dart';
import '../repositories/requests_repository.dart';

/// Controller untuk media per request:
/// - fetch daftar media (dengan signed URL)
/// - upload media baru
/// - hapus media
class MediaController extends ChangeNotifier {
  final RequestsRepository _repo;

  MediaController(this._repo);

  // Map requestId -> daftar media
  final Map<String, List<MediaModel>> _mediaByRequest = {};
  final Map<String, bool> _loadingByRequest = {};
  final Map<String, String?> _errorByRequest = {};

  List<MediaModel> mediaOf(String requestId) =>
      _mediaByRequest[requestId] ?? [];
  bool loadingOf(String requestId) => _loadingByRequest[requestId] == true;
  String? errorOf(String requestId) => _errorByRequest[requestId];

  Future<void> loadMedia(String requestId) async {
    _loadingByRequest[requestId] = true;
    _errorByRequest[requestId] = null;
    notifyListeners();
    try {
      final list = await _repo.fetchMedia(requestId);
      _mediaByRequest[requestId] = list;
    } catch (e) {
      _errorByRequest[requestId] = e.toString();
    } finally {
      _loadingByRequest[requestId] = false;
      notifyListeners();
    }
  }

  Future<bool> upload({
    required String requestId,
    required File file,
    required MediaType type,
    String? caption,
  }) async {
    _loadingByRequest[requestId] = true;
    notifyListeners();
    try {
      final m = await _repo.uploadMedia(
        requestId: requestId,
        file: file,
        type: type,
        caption: caption,
      );
      final list = _mediaByRequest[requestId] ?? [];
      _mediaByRequest[requestId] = [m, ...list];
      _errorByRequest[requestId] = null;
      return true;
    } catch (e) {
      _errorByRequest[requestId] = e.toString();
      return false;
    } finally {
      _loadingByRequest[requestId] = false;
      notifyListeners();
    }
  }

  Future<void> delete(String requestId, MediaModel media) async {
    _loadingByRequest[requestId] = true;
    notifyListeners();
    try {
      await _repo.deleteMedia(media);
      final list = _mediaByRequest[requestId] ?? [];
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
