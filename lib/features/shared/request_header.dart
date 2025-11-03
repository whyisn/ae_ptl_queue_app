import 'package:flutter/material.dart';
import '../../core/utils.dart';
import '../../models/request_model.dart';

class RequestHeaderCard extends StatelessWidget {
  final RequestModel req;
  final int? queuePos; // kalau perlu tampilkan nomor antrian
  const RequestHeaderCard({super.key, required this.req, this.queuePos});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Tampilkan keduanya jika ada; kalau cuma satu, tampil yang ada.
    final List<InlineSpan> identity = [];
    if ((req.externalId ?? '').isNotEmpty) {
      identity.add(
        TextSpan(
          text: req.externalId,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }
    if ((req.externalId ?? '').isNotEmpty &&
        (req.applicantName ?? '').isNotEmpty) {
      identity.add(const TextSpan(text: ' • '));
    }
    if ((req.applicantName ?? '').isNotEmpty) {
      identity.add(TextSpan(text: req.applicantName, style: t.titleMedium));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // if (identity.isNotEmpty)
            //   RichText(
            //     text: TextSpan(style: t.bodyMedium, children: identity),
            //   )
            // else
            if ((req.externalId ?? '').isEmpty && (req.applicantName ?? '').isEmpty)
              Text('-', style: t.titleMedium),
            if ((req.externalId ?? '').isNotEmpty || (req.applicantName ?? '').isNotEmpty)
              Row(
                children: [
                  if ((req.externalId ?? '').isNotEmpty) ...[
                    GestureDetector(
                      onLongPress: () => copyToClipboard(
                        context,
                        req.externalId!,
                        label: 'ID Pemohon',
                      ),
                      child: Text(
                        req.externalId!,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Salin ID',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => copyToClipboard(
                        context,
                        req.externalId!,
                        label: 'ID Pemohon',
                      ),
                    ),
                  ],
                  if ((req.externalId ?? '').isNotEmpty &&
                      (req.applicantName ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Text('•'),
                    const SizedBox(width: 8),
                  ],
                  if ((req.applicantName ?? '').isNotEmpty) ...[
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () => copyToClipboard(
                          context,
                          req.applicantName!,
                          label: 'Nama Pemohon',
                        ),
                        child: Text(req.applicantName!, style: t.titleMedium),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Salin Nama',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => copyToClipboard(
                        context,
                        req.applicantName!,
                        label: 'Nama Pemohon',
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.badge, size: 16),
                const SizedBox(width: 6),
                Text(_statusText(req.status), style: t.bodySmall),
              ],
            ),
            if (queuePos != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Nomor Antrian: $queuePos', style: t.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText(RequestStatus s) {
    switch (s) {
      case RequestStatus.waitingReview:
        return 'Status: Menunggu Review';
      case RequestStatus.revisionRequested:
        return 'Status: Permintaan Revisi';
      case RequestStatus.approved:
        return 'Status: Diterima';
      case RequestStatus.rejected:
        return 'Status: Ditolak';
      case RequestStatus.draft:
        return 'Status: Draft';
    }
  }
}
