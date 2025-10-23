import 'dart:async' show Timer, StreamSubscription;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request_model.dart';
import '../models/user_model.dart';
import '../repositories/requests_repository.dart';

class RequestController extends ChangeNotifier {
  final RequestsRepository _repo;

  RequestController(this._repo);

  // ==== Realtime support (v1 style) ====
  StreamSubscription<List<Map<String, dynamic>>>? _reqSub;
  Timer? _debounce; // untuk menahan reload beruntun
  // heartbeat PTL detail
  Timer? _hb;
  String? _aeIdCache;
  String? _rslIdCache;

  bool loadingMy = false;
  String? errorMy;
  List<RequestModel> myRequests = [];

  bool loadingPTL = false;
  String? errorPTL;
  List<RequestModel> ptlQueue = [];

  bool loadingDetail = false;
  String? errorDetail;
  RequestModel? currentDetail;

  /// === Highlight global: request yang sedang direview (berdasar PTL queue)
  RequestModel? get globallyReviewed {
    try {
      return ptlQueue.firstWhere(
        (e) => e.isBeingReviewed && e.status == RequestStatus.waitingReview,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> loadMyRequests(String aeId) async {
    loadingMy = true;
    notifyListeners();
    try {
      // myRequests = await _repo.fetchMyRequests(aeId);
      myRequests = await _repo.fetchMyRequests(aeId);
      // Guard: buang approved/rejected jika ada yang lolos
      myRequests = myRequests
          .where(
            (r) =>
                r.status == RequestStatus.waitingReview ||
                r.status == RequestStatus.revisionRequested,
          )
          .toList();
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

  // =========================
  // Realtime: API publik
  // =========================
  /// AE: subscribe event realtime untuk RSL tertentu.
  /// Akan auto-reload AE list (dan PTL queue bila diperlukan) ketika ada INSERT/UPDATE/DELETE.
  void startRealtimeForAE({required String aeId, required String rslId}) {
    _aeIdCache = aeId;
    _rslIdCache = rslId;
    _subscribeRequestsChannel(rslId);
  }

  /// PTL: subscribe event realtime untuk RSL tertentu.
  /// Akan auto-reload PTL queue ketika ada perubahan.
  void startRealtimeForPTL({required String rslId}) {
    _aeIdCache = null; // tidak perlu reload AE list untuk mode PTL-only
    _rslIdCache = rslId;
    _subscribeRequestsChannel(rslId);
  }

  // =========================
  // Realtime: implementasi
  // =========================
  void _subscribeRequestsChannel(String rslId) {
    // Batalkan subscription lama agar tidak double-subscribe
    _reqSub?.cancel();

    // // Gunakan stream API: akan push data setiap ada perubahan (INSERT/UPDATE/DELETE)
    // final stream = Supabase.instance.client
    //     .from('requests')
    //     .stream(primaryKey: ['id'])
    //     .eq('rsl_id', rslId); // filter berdasar RSL

    final base = Supabase.instance.client
        .from('requests')
        .stream(primaryKey: ['id']);
    // Jika rslId kosong → subscribe global (supaya tetap realtime)
    final stream = (rslId.isEmpty) ? base : base.eq('rsl_id', rslId);

    _reqSub = stream.listen((rows) {
      // Kita tidak pakai 'rows' langsung; tetap trigger reload ter-debounce
      _onRequestsChange();
    });
  }

  void _onRequestsChange() {
    // Debounce reload agar hemat kuota & smooth
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        // Reload AE list jika konteks AE tersedia
        if (_aeIdCache != null) {
          await loadMyRequests(_aeIdCache!);
        }
        // Reload PTL queue; gunakan API yang sudah ada
        if (_rslIdCache != null) {
          try {
            // Utamakan by-RSL supaya lebih hemat data
            await loadPTLQueueByRsl(_rslIdCache!);
          } catch (_) {
            await loadPTLQueue();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Realtime reload error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hb?.cancel();
    _reqSub?.cancel();
    super.dispose();
  }

  /// Tambahan: AE list berdasar user (pakai rsl jika tersedia)
  Future<void> loadMyRequestsForUser(AppUser user) async {
    loadingMy = true;
    notifyListeners();
    try {
      if (user.rslId != null && user.rslId!.isNotEmpty) {
        myRequests = await _repo.fetchMyRequestsByRsl(
          aeId: user.id,
          rslId: user.rslId!,
        );
      } else {
        myRequests = await _repo.fetchMyRequests(user.id);
      }
      // Guard: buang approved/rejected jika ada yang lolos
      myRequests = myRequests
          .where(
            (r) =>
                r.status == RequestStatus.waitingReview ||
                r.status == RequestStatus.revisionRequested,
          )
          .toList();
      errorMy = null;
    } catch (e) {
      errorMy = e.toString();
    } finally {
      loadingMy = false;
      notifyListeners();
    }
  }

  /// Tambahan: PTL queue berdasar RSL (fallback ke global kalau belum ada rslId)
  Future<void> loadPTLQueueByRsl(String? rslId) async {
    loadingPTL = true;
    notifyListeners();
    try {
      if (rslId != null && rslId.isNotEmpty) {
        ptlQueue = await _repo.fetchAllForPTLByRsl(rslId);
      } else {
        ptlQueue = await _repo.fetchAllForPTL();
      }
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
    String? rslId,
    String? applicantName,
    String? externalId,
    String? aeNote,
  }) async {
    try {
      final r = await _repo.createRequest(
        aeId: aeId,
        rslId: rslId,
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
    // setelah lock, refresh queue agar banner konsisten di semua halaman
    await loadPTLQueueByRsl(_rslIdCache);
  }

  /// Dipanggil dari PTL detail untuk memompa heartbeat tiap 10 dtk
  void startHeartbeat(String requestId) {
    _hb?.cancel();
    _hb = Timer.periodic(const Duration(seconds: 10), (_) {
      _repo.heartbeatReview(requestId);
    });
  }

  void stopHeartbeat() {
    _hb?.cancel();
    _hb = null;
  }

  Future<void> releaseIfStillOpen(String requestId) async {
    await _repo.releaseIfStillOpen(requestId);
  }

  /// Lepaskan lock jika PTL keluar tanpa keputusan
  Future<void> releaseReview(String requestId) async {
    await _repo.releaseReview(requestId);
    await loadPTLQueueByRsl(_rslIdCache);
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
