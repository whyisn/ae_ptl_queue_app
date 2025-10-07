import 'package:flutter/material.dart';

/// Badge status yang dipakai di AE/PTL
/// Terima input:
/// - 'waiting_review', 'revision_requested', 'approved', 'rejected', 'draft'
/// - atau pseudo-status khusus: 'sedang_direview'
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  String _label() {
    switch (status) {
      case 'sedang_direview':
        return 'Sedang Direview';
      case 'waiting_review':
        return 'Menunggu Review';
      case 'revision_requested':
        return 'Permintaan Revisi';
      case 'approved':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  Color _bg(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'sedang_direview':
        return cs.primary.withOpacity(.15);
      case 'waiting_review':
        return Colors.amber.withOpacity(.2);
      case 'revision_requested':
        return Colors.red.withOpacity(.18);
      case 'approved':
        return Colors.green.withOpacity(.18);
      case 'rejected':
        return Colors.red.withOpacity(.18);
      case 'draft':
        return Colors.grey.withOpacity(.2);
      default:
        return Colors.grey.withOpacity(.15);
    }
  }

  Color _fg(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'sedang_direview':
        return cs.primary;
      case 'waiting_review':
        return Colors.amber[800]!;
      case 'revision_requested':
        return Colors.red[700]!;
      case 'approved':
        return Colors.green[700]!;
      case 'rejected':
        return Colors.red[700]!;
      case 'draft':
        return Colors.grey[700]!;
      default:
        return Colors.grey[800]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          color: _fg(context),
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
