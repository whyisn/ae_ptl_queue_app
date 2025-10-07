import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/request_model.dart';

/// Service untuk operasi tabel `requests` + `request_notes`.
class RequestsService {
  final supabase = Supabase.instance.client;

  /// Buat permohonan baru.
  /// - `applicantName` ATAU `externalId` boleh null (salah satu wajib di UI).
  /// - Jika `aeNote` diisi, simpan ke `request_notes` dengan action = 'note'.
  Future<RequestModel> createRequest({
    required String aeId,
    String? applicantName,
    String? externalId,
    String? aeNote,
  }) async {
    final data = await supabase
        .from('requests')
        .insert({
          'ae_id': aeId,
          'applicant_name': applicantName,
          'external_id': externalId,
          'status': 'waiting_review',
          'priority': false,
          'enqueued_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    if (aeNote != null && aeNote.trim().isNotEmpty) {
      await supabase.from('request_notes').insert({
        'request_id': data['id'],
        'author_id': aeId,
        'role_snapshot': 'AE',
        'note': aeNote.trim(),
        // ⬇︎ WAJIB 'note' supaya lolos check-constraint
        'action': 'note',
      });
    }

    return RequestModel.fromMap(data);
  }

  /// Ambil request milik AE saat ini (punya tombol edit/hapus di UI AE).
  Future<List<RequestModel>> fetchMyRequests(String aeId) async {
    final rows = await supabase
        .from('requests')
        .select()
        .eq('ae_id', aeId)
        .order('updated_at', ascending: false);

    return rows.map<RequestModel>((m) => RequestModel.fromMap(m)).toList();
  }

  /// Ambil seluruh antrian untuk PTL dari view (sudah ada `queue_pos`).
  Future<List<RequestModel>> fetchAllForPTL() async {
    final rows = await supabase.from('v_waiting_queue_with_pos').select();
    return rows.map<RequestModel>((m) => RequestModel.fromMap(m)).toList();
  }

  /// Ambil detail request.
  Future<RequestModel?> fetchRequestById(String id) async {
    final row = await supabase
        .from('requests')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : RequestModel.fromMap(row);
  }

  /// Tandai sedang direview oleh PTL (untuk badge “Sedang Direview” di semua AE).
  Future<void> markBeingReviewed(String requestId) async {
    await supabase
        .from('requests')
        .update({
          'reviewed_by': supabase.auth.currentUser!.id,
          'review_started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  /// Approve permohonan.
  Future<void> approve(String requestId, {String? note}) async {
    if (note != null && note.trim().isNotEmpty) {
      await supabase.from('request_notes').insert({
        'request_id': requestId,
        'author_id': supabase.auth.currentUser!.id,
        'role_snapshot': 'PTL',
        'note': note.trim(),
        'action': 'approved',
      });
    }
    await supabase
        .from('requests')
        .update({
          'status': 'approved',
          'priority': false,
          'closed_at': DateTime.now().toIso8601String(),
          'reviewed_by': null,
          'review_started_at': null,
        })
        .eq('id', requestId);
  }

  /// Reject permohonan (note wajib).
  Future<void> reject(String requestId, {required String note}) async {
    await supabase.from('request_notes').insert({
      'request_id': requestId,
      'author_id': supabase.auth.currentUser!.id,
      'role_snapshot': 'PTL',
      'note': note.trim(),
      'action': 'rejected',
    });
    await supabase
        .from('requests')
        .update({
          'status': 'rejected',
          'priority': false,
          'closed_at': DateTime.now().toIso8601String(),
          'reviewed_by': null,
          'review_started_at': null,
        })
        .eq('id', requestId);
  }

  /// PTL minta revisi → request kembali ke `waiting_review` sebagai prioritas.
  Future<void> askRevision(String requestId, {required String note}) async {
    await supabase.from('request_notes').insert({
      'request_id': requestId,
      'author_id': supabase.auth.currentUser!.id,
      'role_snapshot': 'PTL',
      'note': note.trim(),
      'action': 'ask_revision',
    });
    await supabase
        .from('requests')
        .update({
          'status': 'revision_requested',
          'priority': true,
          'reviewed_by': null,
          'review_started_at': null,
        })
        .eq('id', requestId);
  }

  /// Hapus request (AE, selama belum closed).
  Future<void> deleteRequest(String requestId) async {
    await supabase.from('requests').delete().eq('id', requestId);
  }
}
