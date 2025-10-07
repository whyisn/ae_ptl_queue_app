import 'package:flutter/foundation.dart';

import '../models/request_model.dart';
import '../repositories/requests_repository.dart';

/// Controller untuk mengelola state permohonan:
/// - List milik AE (myRequests)
/// - List antrian PTL (ptlQueue)
/// - Operasi: create, delete, approve, reject, revision, markBeingReviewed, refresh detail
class RequestController extends ChangeNotifier {
  final RequestsRepository _repo;

  RequestController(this._repo);

  // ======== State AE ========
  bool loadingMy = false;
  String? errorMy;
  List<RequestModel> myRequests = [];

  // ======== State PTL ========
  bool loadingPTL = false;
  String? errorPTL;
  List<RequestModel> ptlQueue = [];

  // ======== State Detail ========
  bool loadingDetail = false;
  String? errorDetail;
  RequestModel? currentDetail;

  // -------- AE List --------
  Future<void> loadMyRequests(String aeId) async {
    loadingMy = true;
    notifyListeners();
    try {
      myRequests = await _repo.fetchMyRequests(aeId);
      errorMy = null;
    } catch (e) {
      errorMy = e.toString();
    } finally {
      loadingMy = false;
      notifyListeners();
    }
  }

  // -------- PTL Queue --------
  Future<void> loadPTLQueue() async {
    loadingPTL = true;
    notifyListeners();
    try {
      ptlQueue = await _repo.fetchAllForPTL();
      errorPTL = null;
    } catch (e) {
      errorPTL = e.toString();
    } finally {
      loadingPTL = false;
      notifyListeners();
    }
  }

  // -------- Detail --------
  Future<void> loadDetail(String requestId) async {
    loadingDetail = true;
    notifyListeners();
    try {
      currentDetail = await _repo.fetchRequestById(requestId);
      errorDetail = null;
    } catch (e) {
      errorDetail = e.toString();
    } finally {
      loadingDetail = false;
      notifyListeners();
    }
  }

  // -------- AE Actions --------
  Future<RequestModel?> createRequest({
    required String aeId,
    String? applicantName,
    String? externalId,
    String? aeNote,
  }) async {
    try {
      final r = await _repo.createRequest(
        aeId: aeId,
        applicantName: applicantName,
        externalId: externalId,
        aeNote: aeNote,
      );
      // prepend ke list AE
      myRequests = [r, ...myRequests];
      notifyListeners();
      return r;
    } catch (e) {
      errorMy = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteRequest(String requestId, {String? aeId}) async {
    await _repo.deleteRequest(requestId);
    // update list AE jika diberikan aeId
    if (aeId != null) {
      myRequests.removeWhere((e) => e.id == requestId);
      notifyListeners();
    }
  }

  // -------- PTL Actions --------
  Future<void> markBeingReviewed(String requestId) async {
    await _repo.markBeingReviewed(requestId);
    // tidak perlu update state di sini; AE akan melihat perubahan saat fetch ulang
  }

  Future<bool> approve(String requestId, {String? note}) async {
    try {
      await _repo.approve(requestId, note: note);
      // keluarkan dari queue PTL
      ptlQueue.removeWhere((e) => e.id == requestId);
      if (currentDetail?.id == requestId) currentDetail = null;
      notifyListeners();
      return true;
    } catch (e) {
      errorDetail = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reject(String requestId, {required String note}) async {
    try {
      await _repo.reject(requestId, note: note);
      ptlQueue.removeWhere((e) => e.id == requestId);
      if (currentDetail?.id == requestId) currentDetail = null;
      notifyListeners();
      return true;
    } catch (e) {
      errorDetail = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> askRevision(String requestId, {required String note}) async {
    try {
      await _repo.askRevision(requestId, note: note);
      ptlQueue.removeWhere((e) => e.id == requestId);
      if (currentDetail?.id == requestId) currentDetail = null;
      notifyListeners();
      return true;
    } catch (e) {
      errorDetail = e.toString();
      notifyListeners();
      return false;
    }
  }
}
