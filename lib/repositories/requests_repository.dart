import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/request_model.dart';
import '../models/media_model.dart';
import '../services/media_service.dart';

class RequestsRepository {
  final SupabaseClient _sb;
  final MediaService _media;

  RequestsRepository(this._sb) : _media = MediaService();

  // ========= AE LIST (milik AE) + inject queue_pos global =========
  Future<List<RequestModel>> fetchMyRequests(String aeId) async {
    // Ambil semua request milik AE dari table utama
    final baseRows = await _sb
        .from('requests')
        .select('''
          id, ae_id, applicant_name, external_id, status, priority,
          ptl_note_last, enqueued_at, reviewed_by, review_started_at,
          created_at, updated_at, closed_at
        ''')
        .eq('ae_id', aeId)
        .order('created_at', ascending: true);

    final list = (baseRows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const [];

    // Inject queue_pos global dari VIEW untuk ID-ID yang sedang antre (waiting_review)
    final ids = list.map((e) => e['id'] as String).toList();
    if (ids.isEmpty) return const [];

    // Beberapa versi SDK tak punya .in_(), gunakan .or('id.eq.a,id.eq.b,...')
    final idConds = ids.map((id) => 'id.eq.$id').join(',');
    final posRows = await _sb
        .from('v_waiting_queue_with_pos')
        .select('id, queue_pos, ae_name')
        .or(idConds);

    // Ambil catatan AE terakhir untuk semua request tersebut (bulk)
    final notesRows = await _sb
        .from('request_notes')
        .select('request_id, note, created_at')
        .inFilter('request_id', ids)
        .eq('role_snapshot', 'AE')
        .order('created_at', ascending: false);

    // Simpan note AE terbaru per request_id
    final Map<String, String> latestAeNoteByReq = {};
    for (final r in (notesRows as List).cast<Map<String, dynamic>>()) {
      final rid = r['request_id'] as String;
      // jika belum ada, berarti ini yang terbaru (karena sudah diorder desc)
      latestAeNoteByReq.putIfAbsent(rid, () => (r['note'] as String?) ?? '');
    }

    final posMap = <String, Map<String, dynamic>>{
      for (final r in (posRows as List).cast<Map<String, dynamic>>())
        r['id'] as String: r,
    };

    final enriched = list.map((m) {
      final extra = posMap[m['id']];
      if (extra != null) {
        m['queue_pos'] = extra['queue_pos'];
        m['ae_name'] = extra['ae_name'];
      }
      final aeNote = latestAeNoteByReq[m['id']];
      if (aeNote != null && aeNote.isNotEmpty) {
        m['ae_note_last'] = aeNote;
      }
      return RequestModel.fromMap(m);
    }).toList();

    return enriched;
  }

  // ========= PTL QUEUE (global) =========
  Future<List<RequestModel>> fetchAllForPTL() async {
    final rows = await _sb
        .from('v_waiting_queue_with_pos')
        .select('''
          id, ae_id, applicant_name, external_id, status, priority,
          ptl_note_last, enqueued_at, reviewed_by, review_started_at,
          created_at, updated_at, closed_at,
          queue_pos, ae_name
        ''')
        .order('queue_pos', ascending: true);

    return (rows as List)
        .map((m) => RequestModel.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  // ========= DETAIL =========
  Future<RequestModel> fetchRequestById(String id) async {
    final rows = await _sb
        .from('requests')
        .select('''
          id, ae_id, applicant_name, external_id, status, priority,
          ptl_note_last, enqueued_at, reviewed_by, review_started_at,
          created_at, updated_at, closed_at
        ''')
        .eq('id', id)
        .limit(1);

    if ((rows as List).isEmpty) {
      throw Exception('Request not found');
    }
    final m = rows.first as Map<String, dynamic>;

    final posRows = await _sb
        .from('v_waiting_queue_with_pos')
        .select('id, queue_pos, ae_name')
        .eq('id', id)
        .limit(1);

    if ((posRows as List).isNotEmpty) {
      final extra = posRows.first as Map<String, dynamic>;
      m['queue_pos'] = extra['queue_pos'];
      m['ae_name'] = extra['ae_name'];
    }

    // Ambil catatan AE terakhir untuk request ini
    final aeRow = await _sb
        .from('request_notes')
        .select('note, created_at')
        .eq('request_id', id)
        .eq('role_snapshot', 'AE')
        .order('created_at', ascending: false)
        .limit(1);
    if ((aeRow as List).isNotEmpty) {
      m['ae_note_last'] =
          (aeRow.first as Map<String, dynamic>)['note'] as String?;
    }

    return RequestModel.fromMap(m);
  }

  // ========= MUTASI (AE) =========

  /// Membuat permohonan baru. Status default `waiting_review`, priority=false.
  /// Jika [aeNote] diisi, simpan sebagai catatan awal ke tabel `request_notes`.
  Future<RequestModel> createRequest({
    required String aeId,
    String? applicantName,
    String? externalId,
    String? aeNote,
  }) async {
    final insert = await _sb
        .from('requests')
        .insert({
          'ae_id': aeId,
          'applicant_name': applicantName,
          'external_id': externalId,
          'status': 'waiting_review',
          'priority': false,
          'ptl_note_last': null, // catatan PTL terakhir kosong di awal
          'enqueued_at': DateTime.now().toIso8601String(),
        })
        .select('''
          id, ae_id, applicant_name, external_id, status, priority,
          ptl_note_last, enqueued_at, reviewed_by, review_started_at,
          created_at, updated_at, closed_at
        ''')
        .single();

    final reqId = (insert as Map<String, dynamic>)['id'] as String;

    // Jika ada catatan AE, simpan ke log request_notes
    if ((aeNote ?? '').trim().isNotEmpty) {
      await _sb.from('request_notes').insert({
        'request_id': reqId,
        'author_id': aeId,
        'role_snapshot': 'AE',
        'note': aeNote!.trim(),
        'action': 'note',
      });
    }

    return RequestModel.fromMap(insert);
  }

  Future<void> deleteRequest(String id) async {
    await _sb.from('requests').delete().eq('id', id);
  }

  // ========= MUTASI (PTL) =========

  Future<void> markBeingReviewed(String id) async {
    await _sb
        .from('requests')
        .update({
          'reviewed_by': _sb.auth.currentUser?.id,
          'review_started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> approve(String id, {String? note}) async {
    await _sb
        .from('requests')
        .update({
          'status': 'approved',
          'ptl_note_last': note,
          'closed_at': DateTime.now().toIso8601String(),
          'reviewed_by': _sb.auth.currentUser?.id,
        })
        .eq('id', id);

    if ((note ?? '').trim().isNotEmpty) {
      await _sb.from('request_notes').insert({
        'request_id': id,
        'author_id': _sb.auth.currentUser?.id,
        'role_snapshot': 'PTL',
        'note': note!.trim(),
        'action': 'approve',
      });
    }
  }

  Future<void> reject(String id, {required String note}) async {
    await _sb
        .from('requests')
        .update({
          'status': 'rejected',
          'ptl_note_last': note,
          'closed_at': DateTime.now().toIso8601String(),
          'reviewed_by': _sb.auth.currentUser?.id,
        })
        .eq('id', id);

    await _sb.from('request_notes').insert({
      'request_id': id,
      'author_id': _sb.auth.currentUser?.id,
      'role_snapshot': 'PTL',
      'note': note.trim(),
      'action': 'reject',
    });
  }

  Future<void> askRevision(String id, {required String note}) async {
    await _sb
        .from('requests')
        .update({
          'status': 'revision_requested',
          'ptl_note_last': note,
          'reviewed_by': _sb.auth.currentUser?.id,
        })
        .eq('id', id);

    await _sb.from('request_notes').insert({
      'request_id': id,
      'author_id': _sb.auth.currentUser?.id,
      'role_snapshot': 'PTL',
      'note': note.trim(),
      'action': 'revision',
    });
  }

  // ========= MEDIA (delegasi ke MediaService kamu) =========

  Future<List<MediaModel>> fetchMedia(String requestId) =>
      _media.fetchMedia(requestId);

  Future<MediaModel> uploadMedia({
    required String requestId,
    required File file,
  }) {
    // Tebak tipe dari ekstensi sederhana
    final lower = file.path.toLowerCase();
    final isVideo =
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
    final type = isVideo ? MediaType.video : MediaType.image;
    return _media.uploadMedia(requestId: requestId, file: file, type: type);
  }

  Future<void> deleteMedia(MediaModel media) => _media.deleteMedia(media);
}
