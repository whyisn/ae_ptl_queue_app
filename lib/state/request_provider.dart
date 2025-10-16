import 'package:flutter/foundation.dart';
import '../models/request_model.dart';
import '../repositories/requests_repository.dart';

class RequestController extends ChangeNotifier {
  final RequestsRepository _repo;

  RequestController(this._repo);

  bool loadingMy = false;
  String? errorMy;
  List<RequestModel> myRequests = [];

  bool loadingPTL = false;
  String? errorPTL;
  List<RequestModel> ptlQueue = [];

  bool loadingDetail = false;
  String? errorDetail;
  RequestModel? currentDetail;

  Future<void> loadMyRequests(String aeId) async {
    loadingMy = true;
    notifyListeners();
    try {
      myRequests = await _repo.fetchMyRequests(aeId);
      debugPrint(
        '>>> C. Jumlah RequestModel di Provider: ${myRequests.length}',
      );
      errorMy = null;
    } catch (e) {
      errorMy = e.toString();
    } finally {
      loadingMy = false;
      notifyListeners();
    }
  }

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
      await loadMyRequests(aeId); // REFRESH
      return r;
    } catch (e) {
      errorMy = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteRequest(String requestId, {String? aeId}) async {
    await _repo.deleteRequest(requestId);
    if (aeId != null) {
      await loadMyRequests(aeId); // REFRESH
    }
  }

  Future<void> markBeingReviewed(String requestId) async {
    await _repo.markBeingReviewed(requestId);
  }

  Future<bool> approve(String requestId, {String? note}) async {
    try {
      await _repo.approve(requestId, note: note);
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
