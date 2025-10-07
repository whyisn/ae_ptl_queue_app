import 'dart:io';
import '../models/request_model.dart';
import '../models/media_model.dart';
import '../services/requests_service.dart';
import '../services/media_service.dart';

/// Repository ini menggabungkan operasi request + media + sedikit logika kecil
class RequestsRepository {
  final RequestsService _req;
  final MediaService _media;

  RequestsRepository({
    RequestsService? requestsService,
    MediaService? mediaService,
  }) : _req = requestsService ?? RequestsService(),
       _media = mediaService ?? MediaService();

  /// Buat permohonan baru (AE)
  Future<RequestModel> createRequest({
    required String aeId,
    String? applicantName,
    String? externalId,
    String? aeNote,
  }) {
    return _req.createRequest(
      aeId: aeId,
      applicantName: applicantName,
      externalId: externalId,
      aeNote: aeNote,
    );
  }

  /// Ambil list permohonan milik AE
  Future<List<RequestModel>> fetchMyRequests(String aeId) async {
    return _req.fetchMyRequests(aeId);
  }

  /// Ambil antrian global untuk PTL (hanya waiting_review)
  Future<List<RequestModel>> fetchAllForPTL() async {
    return _req.fetchAllForPTL();
  }

  /// Detail request
  Future<RequestModel?> fetchRequestById(String id) =>
      _req.fetchRequestById(id);

  /// Media: upload (otomatis insert request_media & upload ke bucket)
  Future<MediaModel> uploadMedia({
    required String requestId,
    required File file,
    required MediaType type,
    String? caption,
  }) {
    return _media.uploadMedia(
      requestId: requestId,
      file: file,
      type: type,
      caption: caption,
    );
  }

  /// Media: ambil media + signed URL
  Future<List<MediaModel>> fetchMedia(String requestId) {
    return _media.fetchMedia(requestId);
  }

  /// Media: hapus
  Future<void> deleteMedia(MediaModel m) => _media.deleteMedia(m);

  /// PTL membuka detail → tandai sedang direview (muncul badge di AE)
  Future<void> markBeingReviewed(String requestId) =>
      _req.markBeingReviewed(requestId);

  /// PTL aksi: approve (opsional dengan catatan)
  Future<void> approve(String requestId, {String? note}) =>
      _req.approve(requestId, note: note);

  /// PTL aksi: tolak (WAJIB catatan)
  Future<void> reject(String requestId, {required String note}) =>
      _req.reject(requestId, note: note);

  /// PTL aksi: minta revisi (WAJIB catatan) → prioritas, kembali ke AE
  Future<void> askRevision(String requestId, {required String note}) =>
      _req.askRevision(requestId, note: note);

  /// AE hapus permohonan (sebelum ditutup)
  Future<void> deleteRequest(String requestId) => _req.deleteRequest(requestId);
}
