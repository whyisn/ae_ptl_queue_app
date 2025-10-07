import 'package:flutter/material.dart';
import '../../../core/utils.dart';
import '../../../models/request_model.dart';

class PTLRequestTile extends StatelessWidget {
  final RequestModel data;
  final VoidCallback? onTap;

  const PTLRequestTile({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = <Widget>[
      const SizedBox(height: 6),
      Text(
        'Status: ${friendlyStatusForPTL(data.toMap())}',
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
        title: Text(
          data.displayApplicant,
          style: const TextStyle(fontWeight: FontWeight.w600),
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
