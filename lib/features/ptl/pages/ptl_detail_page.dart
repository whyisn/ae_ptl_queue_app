import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils.dart';
import '../../../state/auth_provider.dart';
import '../../../state/media_provider.dart';
import '../../../state/request_provider.dart';
import '../../shared/media_preview.dart';

class PTLDetailPage extends StatefulWidget {
  final String requestId;
  const PTLDetailPage({super.key, required this.requestId});

  @override
  State<PTLDetailPage> createState() => _PTLDetailPageState();
}

class _PTLDetailPageState extends State<PTLDetailPage> {
  final _noteC = TextEditingController();
  bool loading = true;
  String? error;
  bool _processing = false;
  bool _decided = false; // true kalau approve/reject/revision dipanggil

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

      // tandai sedang direview
      await reqCtrl.markBeingReviewed(widget.requestId);

      await reqCtrl.loadDetail(widget.requestId);
      await mediaCtrl.loadMedia(widget.requestId);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _approve() async {
    if (_processing) return;
    setState(() => _processing = true);
    final reqCtrl = context.read<RequestController>();
    final ok = await reqCtrl.approve(
      widget.requestId,
      note: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _decided = true;
      showSnack(context, 'Permohonan diterima');
      Navigator.pop(context, true);
    } else {
      showSnack(context, reqCtrl.errorDetail ?? 'Gagal approve', error: true);
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _reject() async {
    if (_noteC.text.trim().isEmpty) {
      showSnack(context, 'Catatan wajib diisi untuk menolak', error: true);
      return;
    }
    if (_processing) return;
    setState(() => _processing = true);
    final reqCtrl = context.read<RequestController>();
    final ok = await reqCtrl.reject(widget.requestId, note: _noteC.text.trim());
    if (!mounted) return;
    if (ok) {
      _decided = true;
      showSnack(context, 'Permohonan ditolak');
      Navigator.pop(context, true);
    } else {
      showSnack(context, reqCtrl.errorDetail ?? 'Gagal tolak', error: true);
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _revision() async {
    if (_noteC.text.trim().isEmpty) {
      showSnack(context, 'Catatan revisi wajib diisi', error: true);
      return;
    }
    if (_processing) return;
    setState(() => _processing = true);
    final reqCtrl = context.read<RequestController>();
    final ok = await reqCtrl.askRevision(
      widget.requestId,
      note: _noteC.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _decided = true;
      showSnack(context, 'Permintaan revisi dikirim (prioritas)');
      Navigator.pop(context, true);
    } else {
      showSnack(
        context,
        reqCtrl.errorDetail ?? 'Gagal kirim revisi',
        error: true,
      );
    }
    if (mounted) setState(() => _processing = false);
  }

  @override
  void dispose() {
    _noteC.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // Jika belum mengambil keputusan, lepaskan lock
    if (!_decided) {
      final reqCtrl = context.read<RequestController>();
      await reqCtrl.releaseReview(widget.requestId);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final reqCtrl = context.watch<RequestController>();
    final mediaCtrl = context.watch<MediaController>();
    final d = reqCtrl.currentDetail;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Permohonan (PTL)'),
          actions: [
            IconButton(
              onPressed: () => auth.logout(),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
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
                  // === Header Identitas ===
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
                          const SizedBox(height: 6),
                          Text('Status: ${friendlyStatusForPTL(d.toMap())}'),
                          if ((d.aeName ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Diajukan oleh: ${d.aeName!}'),
                            ),
                          if (d.priority)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'PRIORITAS',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Dokumentasi:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  MediaPreview(
                    media: mediaCtrl
                        .mediaOf(widget.requestId)
                        .map((m) => m.toMap())
                        .toList(),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Catatan PTL (wajib untuk Tolak/Revisi):',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteC,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Tulis catatan review…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _processing ? null : _revision,
                          child: const Text('Revisi'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _processing ? null : _approve,
                          child: const Text('Terima'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _processing ? null : _reject,
                          child: const Text('Tolak'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        floatingActionButton: IconButton(
          tooltip: 'Refresh',
          onPressed: _processing ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
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
