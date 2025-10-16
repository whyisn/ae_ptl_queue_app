import 'package:flutter/foundation.dart';

enum RequestStatus {
  draft,
  waitingReview,
  revisionRequested,
  approved,
  rejected,
}

RequestStatus requestStatusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'waiting_review':
      return RequestStatus.waitingReview;
    case 'revision_requested':
      return RequestStatus.revisionRequested;
    case 'approved':
      return RequestStatus.approved;
    case 'rejected':
      return RequestStatus.rejected;
    case 'draft':
    default:
      return RequestStatus.draft;
  }
}

String requestStatusToString(RequestStatus s) {
  switch (s) {
    case RequestStatus.waitingReview:
      return 'waiting_review';
    case RequestStatus.revisionRequested:
      return 'revision_requested';
    case RequestStatus.approved:
      return 'approved';
    case RequestStatus.rejected:
      return 'rejected';
    case RequestStatus.draft:
    default:
      return 'draft';
  }
}

/// Model permohonan (requests)
class RequestModel {
  final String id;
  final String aeId;

  final String? applicantName; // Nama Pemohon (opsional)
  final String? externalId; // ID Pemohon (opsional)

  final RequestStatus status;
  final bool priority;

  final String? ptlNoteLast;
  final String? aeNoteLast;

  final DateTime? enqueuedAt;
  final String? reviewedBy; // uid PTL
  final DateTime? reviewStartedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  // Bidang opsional dari view PTL
  final int? queuePos; // v_waiting_queue_with_pos
  final String? aeName; // v_waiting_queue_with_pos

  const RequestModel({
    required this.id,
    required this.aeId,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.applicantName,
    this.externalId,
    this.ptlNoteLast,
    this.aeNoteLast,
    this.enqueuedAt,
    this.reviewedBy,
    this.reviewStartedAt,
    this.closedAt,
    this.queuePos,
    this.aeName,
  });

  /// Menentukan display utama di list: jika externalId ada → pakai itu, kalau tidak → applicantName
  String get displayApplicant => (externalId?.trim().isNotEmpty ?? false)
      ? externalId!.trim()
      : (applicantName?.trim().isNotEmpty ?? false)
      ? applicantName!.trim()
      : '-';

  bool get isBeingReviewed =>
      status == RequestStatus.waitingReview && reviewedBy != null;

  factory RequestModel.fromMap(Map<String, dynamic> m) {
    DateTime? dt(String? v) => (v == null) ? null : DateTime.tryParse(v);

    return RequestModel(
      id: m['id'] as String,
      aeId: m['ae_id'] as String,
      applicantName: m['applicant_name'] as String?,
      externalId: m['external_id'] as String?,
      status: requestStatusFromString(m['status'] as String?),
      priority: (m['priority'] as bool?) ?? false,
      ptlNoteLast: m['ptl_note_last'] as String?,
      aeNoteLast: m['ae_note_last'] as String?,
      enqueuedAt: dt(m['enqueued_at'] as String?),
      reviewedBy: m['reviewed_by'] as String?,
      reviewStartedAt: dt(m['review_started_at'] as String?),
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      closedAt: dt(m['closed_at'] as String?),
      queuePos: m['queue_pos'] is int
          ? m['queue_pos'] as int?
          : (m['queue_pos'] as num?)?.toInt(),
      aeName: m['ae_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'ae_id': aeId,
    'applicant_name': applicantName,
    'external_id': externalId,
    'status': requestStatusToString(status),
    'priority': priority,
    'ptl_note_last': ptlNoteLast,
    'ae_note_last': aeNoteLast,
    'enqueued_at': enqueuedAt?.toIso8601String(),
    'reviewed_by': reviewedBy,
    'review_started_at': reviewStartedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
    // field view opsional tidak diinsert/update
  };

  RequestModel copyWith({
    String? id,
    String? aeId,
    String? applicantName,
    String? externalId,
    RequestStatus? status,
    bool? priority,
    String? ptlNoteLast,
    String? aeNoteLast,
    DateTime? enqueuedAt,
    String? reviewedBy,
    DateTime? reviewStartedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? closedAt,
    int? queuePos,
    String? aeName,
  }) {
    return RequestModel(
      id: id ?? this.id,
      aeId: aeId ?? this.aeId,
      applicantName: applicantName ?? this.applicantName,
      externalId: externalId ?? this.externalId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      ptlNoteLast: ptlNoteLast ?? this.ptlNoteLast,
      aeNoteLast: aeNoteLast ?? this.aeNoteLast,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewStartedAt: reviewStartedAt ?? this.reviewStartedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: closedAt ?? this.closedAt,
      queuePos: queuePos ?? this.queuePos,
      aeName: aeName ?? this.aeName,
    );
  }

  @override
  String toString() =>
      'RequestModel(id: $id, status: ${requestStatusToString(status)}, '
      'priority: $priority, display: $displayApplicant, queuePos: $queuePos, beingReviewed: $isBeingReviewed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, updatedAt);
}
