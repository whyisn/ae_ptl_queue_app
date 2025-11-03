import 'package:flutter/material.dart';
import '../../../core/utils.dart';
import '../../../models/request_model.dart';

class PTLRequestTile extends StatelessWidget {
  final RequestModel data;
  final VoidCallback? onTap;

  const PTLRequestTile({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Ambil teks status dari helper yang sudah diperbaiki
    final statusText = friendlyStatusForPTL(data.toMap());
    final subtitle = <Widget>[
      const SizedBox(height: 6),
      Text(
        'Status: $statusText',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      if (data.aeName != null && data.aeName!.isNotEmpty)
        Text('AE: ${data.aeName!}'),
      if (data.queuePos != null) Text('Nomor Antrian: ${data.queuePos}'),
      if (data.priority)
        const Text('PRIORITAS', style: TextStyle(color: Colors.red)),
    ];

    return Card(
      child: ListTile(
        onTap: onTap,
        // title: Text(
        //   data.displayApplicant,
        //   style: const TextStyle(fontWeight: FontWeight.w600),
        // ),
        title: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onLongPress: () => copyToClipboard(
                  context,
                  data.displayApplicant,
                  label: 'ID/Nama',
                ),
                child: Text(
                  data.displayApplicant,
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
                data.displayApplicant,
                label: 'ID/Nama',
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subtitle,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
