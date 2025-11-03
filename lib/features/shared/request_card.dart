import 'package:flutter/material.dart';
import '../../core/utils.dart';
import '../../models/request_model.dart';
import 'status_badge.dart';

/// Kartu ringkas untuk menampilkan permohonan di list.
/// Dipakai generik (termasuk versi awal PTLHome), tetapi Anda bisa
/// tetap memakai tile khusus PTL (ptl_request_tile.dart) bila diinginkan.
class RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final Widget? trailing;

  const RequestCard({super.key, required this.data, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    // Map -> RequestModel untuk utilitas
    final model = RequestModel.fromMap(data);

    final String statusKey = model.isBeingReviewed
        ? 'sedang_direview'
        : requestStatusToString(model.status);

    return Card(
      child: ListTile(
        onTap: onTap,
        // title: Text(
        //   model.displayApplicant,
        //   style: const TextStyle(fontWeight: FontWeight.w600),
        // ),
        title: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onLongPress: () => copyToClipboard(
                  context,
                  model.displayApplicant,
                  label: 'ID/Nama',
                ),
                child: Text(
                  model.displayApplicant,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Salin',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => copyToClipboard(
                context,
                model.displayApplicant,
                label: 'ID/Nama',
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(status: statusKey),
              if (model.priority)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'PRIORITAS',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (model.queuePos != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Nomor Antrian: ${model.queuePos}'),
                    ],
                  ),
                ),
              if ((data['ae_name'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('AE: ${data['ae_name']}'),
                ),
            ],
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
      ),
    );
  }
}
