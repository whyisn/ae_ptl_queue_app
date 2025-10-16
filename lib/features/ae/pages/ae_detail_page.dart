import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils.dart';
import '../../../models/request_model.dart';
import '../../../state/auth_provider.dart';
import '../../../state/media_provider.dart';
import '../../../state/request_provider.dart';
import '../../shared/media_preview.dart';

class AEDetailPage extends StatefulWidget {
  final String requestId;
  const AEDetailPage({super.key, required this.requestId});

  @override
  State<AEDetailPage> createState() => _AEDetailPageState();
}

class _AEDetailPageState extends State<AEDetailPage> {
  bool loading = true;
  String? error;
  int? queuePos;
  String? aeNote;
  String? ptlNote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final reqCtrl = context.read<RequestController>();
      final mediaCtrl = context.read<MediaController>();
      await reqCtrl.loadDetail(widget.requestId);
      await mediaCtrl.loadMedia(widget.requestId);

      final d = reqCtrl.currentDetail;
      if (d == null) throw Exception('Data tidak ditemukan');

      // Nomor antrian hanya saat waiting_review dan belum di-take PTL.
      if (d.status == RequestStatus.waitingReview && d.reviewedBy == null) {
        final sb = Supabase.instance.client;
        final pos = await sb.rpc('queue_position', params: {'req_id': d.id});
        setState(() => queuePos = (pos as int?) ?? 0);
      } else {
        setState(() => queuePos = null);
      }

      // Catatan terakhir AE/PTL (opsional)
      final sb = Supabase.instance.client;
      final ae = await sb
          .from('request_notes')
          .select('note')
          .eq('request_id', d.id)
          .eq('role_snapshot', 'AE')
          .order('created_at', ascending: false)
          .limit(1);
      final ptl = await sb
          .from('request_notes')
          .select('note')
          .eq('request_id', d.id)
          .eq('role_snapshot', 'PTL')
          .order('created_at', ascending: false)
          .limit(1);
      setState(() {
        aeNote = (ae is List && ae.isNotEmpty)
            ? (ae.first['note'] as String?)
            : null;
        ptlNote = (ptl is List && ptl.isNotEmpty)
            ? (ptl.first['note'] as String?)
            : null;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reqCtrl = context.watch<RequestController>();
    final mediaCtrl = context.watch<MediaController>();
    final auth = context.watch<AuthController>();
    final d = reqCtrl.currentDetail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Permohonan'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null || d == null)
          ? Center(child: Text(error ?? 'Data tidak ditemukan'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // === Header Identitas (tampilkan ID &/atau Nama) ===
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ApplicantIdentity(
                          id: d.externalId,
                          name: d.applicantName,
                        ),
                        const SizedBox(height: 8),
                        Text('Status: ${friendlyStatusForAE(d.toMap())}'),
                        if (queuePos != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.confirmation_number_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text('Nomor Antrian: $queuePos'),
                            ],
                          ),
                        ],
                        if (d.priority)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'PRIORITAS',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (aeNote != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Catatan AE:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(aeNote!),
                ],
                if (ptlNote != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Catatan PTL:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(ptlNote!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),

                // === Grid Media (klik → fullscreen) ===
                const Text(
                  'Dokumentasi:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                MediaPreview(
                  media: mediaCtrl
                      .mediaOf(widget.requestId)
                      .map((e) => e.toMap())
                      .toList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }
}

class _ApplicantIdentity extends StatelessWidget {
  final String? id;
  final String? name;
  const _ApplicantIdentity({required this.id, required this.name});

  @override
  Widget build(BuildContext context) {
    final idStr = (id ?? '').trim();
    final nameStr = (name ?? '').trim();
    final hasId = idStr.isNotEmpty;
    final hasName = nameStr.isNotEmpty;

    if (!hasId && !hasName) {
      return const Text(
        '-',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );
    }

    if (hasId && hasName) {
      return Row(
        children: [
          Text(
            idStr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          const Text('•'),
          const SizedBox(width: 8),
          Text(nameStr, style: const TextStyle(fontSize: 16)),
        ],
      );
    }

    final text = hasId ? idStr : nameStr;
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}
