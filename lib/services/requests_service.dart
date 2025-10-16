import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // <-- TAMBAHKAN BARIS INI

import '../models/request_model.dart';

/// Service untuk operasi tabel `requests` + `request_notes`.
class RequestsService {
  final supabase = Supabase.instance.client;

  /// Flatten join & normalisasi kolom waktu menjadi String ISO agar
  /// aman untuk `RequestModel.fromMap` (yang mengharapkan String).
  Map<String, dynamic> _flat(Map<String, dynamic> src) {
    final m = Map<String, dynamic>.from(src);

    // Ambil queue_pos dari view (join left)
    final vw = m['v_waiting_queue_with_pos'];
    if (vw is Map && vw['queue_pos'] != null) {
      m['queue_pos'] = vw['queue_pos'];
    }

    // Ambil ae_name dari join users
    final u = m['users'];
    if (u is Map && u['name'] != null) {
      m['ae_name'] = u['name'];
    }

    // Normalisasi timestamp → String ISO
    String? iso(dynamic v) => (v == null)
        ? null
        : (v is String ? v : (v as DateTime).toIso8601String());
    for (final k in const [
      'created_at',
      'updated_at',
      'enqueued_at',
      'review_started_at',
      'closed_at',
    ]) {
      m[k] = iso(m[k]);
    }
    return m;
  }

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

    // return RequestModel.fromMap(data);
    return RequestModel.fromMap(_flat(Map<String, dynamic>.from(data)));
  }

  /// Ambil request milik AE saat ini (punya tombol edit/hapus di UI AE).
  // Future<List<RequestModel>> fetchMyRequests(String aeId) async {
  //   final rows = await supabase
  //       .from('requests')
  //       .select()
  //       .eq('ae_id', aeId)
  //       .order('updated_at', ascending: false);

  //   return rows.map<RequestModel>((m) => RequestModel.fromMap(m)).toList();
  // }

  Future<List<RequestModel>> fetchMyRequests(String aeId) async {
    final rows = await supabase
        .from('requests')
        .select(r'''
          id, ae_id, applicant_name, external_id, status, priority,
          ptl_note_last, ae_note_last, enqueued_at,
          reviewed_by, review_started_at, created_at, updated_at, closed_at,
          v_waiting_queue_with_pos!left(queue_pos),
          users!requests_ae_id_fkey(name)
        ''')
        .eq('ae_id', aeId)
        .order('created_at', ascending: false);

    debugPrint(
      '>>> B. Hasil Supabase Rows (raw count): ${(rows as List).length}',
    );

    return (rows as List)
        .map((e) => RequestModel.fromMap(_flat(Map<String, dynamic>.from(e))))
        .toList();
  }

  /// Ambil seluruh antrian untuk PTL dari view (sudah ada `queue_pos`).
  Future<List<RequestModel>> fetchAllForPTL() async {
    // final rows = await supabase.from('v_waiting_queue_with_pos').select();
    // return rows.map<RequestModel>((m) => RequestModel.fromMap(m)).toList();
    final rows = await supabase.from('v_waiting_queue_with_pos').select();
    return (rows as List)
        .map((e) => RequestModel.fromMap(_flat(Map<String, dynamic>.from(e))))
        .toList();
  }

  /// Ambil detail request.
  Future<RequestModel?> fetchRequestById(String id) async {
    // final row = await supabase
    //     .from('requests')
    //     .select()
    //     .eq('id', id)
    //     .maybeSingle();
    // return row == null ? null : RequestModel.fromMap(row);
    final row = await supabase
        .from('requests')
        .select(r'''
          id, ae_id, applicant_name, external_id, status, priority,
          ptl_note_last, ae_note_last, enqueued_at,
          reviewed_by, review_started_at, created_at, updated_at, closed_at,
          v_waiting_queue_with_pos!left(queue_pos),
          users!requests_ae_id_fkey(name)
        ''')
        .eq('id', id)
        .maybeSingle();
    return row == null
        ? null
        : RequestModel.fromMap(_flat(Map<String, dynamic>.from(row)));
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
        'action': 'approve',
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
      'action': 'reject',
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
      'action': 'revision',
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
