import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// =====================
/// VALIDATOR FORM BAKU
/// =====================
String? requiredEmailValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
  final re = RegExp(r'^\S+@\S+\.\S+$');
  if (!re.hasMatch(v.trim())) return 'Format email tidak valid';
  return null;
}

String? requiredPasswordValidator(String? v) {
  if (v == null || v.isEmpty) return 'Password wajib diisi';
  if (v.length < 6) return 'Panjang password minimal 6 karakter';
  return null;
}

/// Minimal salah satu harus diisi (nama / ID)
String? optionalButRequireOneOfTwo({
  required String? a,
  required String? b,
  String labelA = 'Nama Pemohon',
  String labelB = 'ID Pemohon',
}) {
  final aa = (a ?? '').trim();
  final bb = (b ?? '').trim();
  if (aa.isEmpty && bb.isEmpty) {
    return 'Isi salah satu: $labelA atau $labelB';
  }
  return null;
}

/// =====================
/// FORMAT & HELPER UI
/// =====================
String formatDateTime(DateTime? dt, {bool withTime = true}) {
  if (dt == null) return '-';
  final locale = 'id_ID';
  if (withTime) {
    return DateFormat('dd MMM yyyy • HH:mm', locale).format(dt);
  }
  return DateFormat('dd MMM yyyy', locale).format(dt);
}

/// Map status dari DB → label ramah untuk AE
String friendlyStatusForAE(Map<String, dynamic> row) {
  // final s = (row['status'] as String?) ?? '';
  // final reviewedBy = row['reviewed_by'];
  // if (s == 'waiting_review' && reviewedBy != null) return 'Sedang Direview';
  final s = (row['status'] as String?) ?? '';
  final reviewedBy = row['reviewed_by'];
  final hb = row['review_heartbeat_at'] as String?;
  bool active = false;
  if (hb != null) {
    final t = DateTime.tryParse(hb);
    if (t != null)
      active = DateTime.now().difference(t) < const Duration(seconds: 20);
  }
  if (s == 'waiting_review' && reviewedBy != null && active)
    return 'Sedang Direview';
  switch (s) {
    case 'waiting_review':
      return 'Menunggu Review';
    case 'revision_requested':
      return 'Permintaan Revisi';
    case 'approved':
      return 'Diterima';
    case 'rejected':
      return 'Ditolak';
    default:
      return s;
  }
}

/// Map status dari DB → label ramah untuk PTL
String friendlyStatusForPTL(Map<String, dynamic> row) {
  // final s = (row['status'] as String?) ?? '';
  // // Di detail PTL, saat dibuka dianggap "Sedang Direview"
  // if (s == 'waiting_review') return 'Sedang Direview';
  // switch (s) {
  //   case 'revision_requested':
  //     return 'Permintaan Revisi';
  //   case 'approved':
  //     return 'Diterima';
  //   case 'rejected':
  //     return 'Ditolak';
  //   default:
  //     return s;
  // }
  // final s = (row['status'] as String?) ?? '';
  // final reviewedBy = row['reviewed_by'];
  // // "Sedang Direview" HANYA jika sudah dipegang PTL (reviewed_by != null)
  // if (reviewedBy != null && s == 'waiting_review') {
  //   return 'Sedang Direview';
  // }
  final s = (row['status'] as String?) ?? '';
  final reviewedBy = row['reviewed_by'];
  final hb = row['review_heartbeat_at'] as String?;
  bool active = false;
  if (hb != null) {
    final t = DateTime.tryParse(hb);
    if (t != null)
      active = DateTime.now().difference(t) < const Duration(seconds: 20);
  }
  if (s == 'waiting_review' && reviewedBy != null && active)
    return 'Sedang Direview';
  switch (s) {
    case 'waiting_review':
      return 'Menunggu Review';
    case 'revision_requested':
      return 'Permintaan Revisi';
    case 'approved':
      return 'Diterima';
    case 'rejected':
      return 'Ditolak';
    default:
      return s;
  }
}

/// Ambil nilai yang ditampilkan di list: jika ID ada pakai ID, jika tidak pakai Nama
String applicantDisplay(Map<String, dynamic> row) {
  final id = (row['external_id'] as String?)?.trim();
  if (id != null && id.isNotEmpty) return id;
  final name = (row['applicant_name'] as String?)?.trim();
  return (name != null && name.isNotEmpty) ? name : '-';
}

/// SnackBar helper
void showSnack(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
  );
}

/// Debouncer sederhana (untuk pencarian, dsb.)
class Debouncer {
  Debouncer({this.milliseconds = 450});
  final int milliseconds;
  VoidCallback? _action;
  bool _active = false;

  void run(VoidCallback action) {
    _action = action;
    if (_active) return;
    _active = true;
    Future.delayed(Duration(milliseconds: milliseconds), () {
      _active = false;
      final a = _action;
      _action = null;
      a?.call();
    });
  }
}
