import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils.dart';
import '../../../models/media_model.dart';
import '../../../models/request_model.dart';
import '../../../services/media_service.dart';
import '../../../services/requests_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/media_provider.dart';
import '../../../state/request_provider.dart';

/// ---------- Helper model untuk file yang DIPILIH tapi BELUM di-upload ----------
class _PendingMedia {
  final File file;
  final MediaType type;
  final String name;

  _PendingMedia({required this.file, required this.type, required this.name});
}

class AEFormPage extends StatefulWidget {
  /// null => create. not null => edit
  final String? requestId;
  const AEFormPage({super.key, this.requestId});

  @override
  State<AEFormPage> createState() => _AEFormPageState();
}

class _AEFormPageState extends State<AEFormPage> {
  final _form = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _extIdC = TextEditingController();
  final _noteC = TextEditingController();

  bool _submitting = false;
  RequestModel? _existing;

  /// daftar file yang sudah dipilih user, belum di-upload
  final List<_PendingMedia> _pending = [];

  /// service (langsung, agar self-contained)
  final _reqSvc = RequestsService();
  final _medSvc = MediaService();

  @override
  void initState() {
    super.initState();

    if (widget.requestId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final reqCtrl = context.read<RequestController>();
        await reqCtrl.loadDetail(widget.requestId!);
        setState(() {
          _existing = reqCtrl.currentDetail;
          _nameC.text = _existing?.applicantName ?? '';
          _extIdC.text = _existing?.externalId ?? '';
        });

        // load media yang sudah ter-upload
        await context.read<MediaController>().loadMedia(widget.requestId!);
      });
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _extIdC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  // ================== PICK MEDIA (HANYA PILIH, TIDAK UPLOAD) ==================
  Future<void> _pickMedia() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi', 'mkv'],
    );
    if (res == null) return;

    final picked = <_PendingMedia>[];
    for (final f in res.files) {
      final path = f.path;
      if (path == null) continue;

      final file = File(path);
      final lower = path.toLowerCase();
      final isVideo =
          lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.avi') ||
          lower.endsWith('.mkv');

      picked.add(
        _PendingMedia(
          file: file,
          type: isVideo ? MediaType.video : MediaType.image,
          name: f.name,
        ),
      );
    }

    if (picked.isNotEmpty) {
      setState(() => _pending.addAll(picked));
      showSnack(context, '${picked.length} file ditambahkan (belum diunggah).');
    }
  }

  // ============== ENSURE REQUEST: buat kalau belum ada (AUTO) ==================
  Future<RequestModel> _ensureRequest(AuthController auth) async {
    if (_existing != null) return _existing!;

    // Validasi "salah satu wajib diisi"
    final err = optionalButRequireOneOfTwo(a: _nameC.text, b: _extIdC.text);
    if (err != null) {
      throw Exception(err);
    }

    final created = await _reqSvc.createRequest(
      aeId: auth.user!.id,
      rslId: auth.user!.rslId, // ⬅️ penting: bind ke RSL user AE
      applicantName: _nameC.text.trim().isEmpty ? null : _nameC.text.trim(),
      externalId: _extIdC.text.trim().isEmpty ? null : _extIdC.text.trim(),
      aeNote: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
    );

    setState(() => _existing = created);

    // Pastikan catatan AE tersimpan saat create (jika ada).
    // Aman dipanggil di sini sekalipun service juga mendukung aeNote—hindari duplikasi by constraint/logika backend.
    if (_noteC.text.trim().isNotEmpty) {
      await Supabase.instance.client.from('request_notes').insert({
        'request_id': created.id,
        'author_id': auth.user!.id,
        'role_snapshot': 'AE',
        'note': _noteC.text.trim(),
        'action': 'note', // wajib 'note' agar lolos constraint
      });
    }
    return created;
  }

  // ============================== SUBMIT ALL ==================================
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    // Enforce salah satu wajib diisi (tambahan selain hint)
    if (_nameC.text.trim().isEmpty && _extIdC.text.trim().isEmpty) {
      showSnack(
        context,
        'Isi salah satu: Nama Pemohon atau ID Pemohon',
        error: true,
      );
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthController>();
    final mediaCtrl = context.read<MediaController>();

    // ====== VALIDASI WAJIB: minimal 1 media (pending atau sudah terunggah) ======
    final currentRid = widget.requestId ?? _existing?.id;
    final alreadyUploaded = currentRid == null
        ? const []
        : mediaCtrl.mediaOf(currentRid);
    final hasAtLeastOneMedia =
        _pending.isNotEmpty || alreadyUploaded.isNotEmpty;
    if (!hasAtLeastOneMedia) {
      showSnack(
        context,
        'Wajib unggah minimal 1 media (foto/video).',
        error: true,
      );
      if (mounted) setState(() => _submitting = false);
      return;
    }

    try {
      // 1) Pastikan request ada (auto create bila perlu)
      final req = await _ensureRequest(auth);

      // 2) Kalau edit: perbarui nilai basic (kalau user mengubah input)
      if (widget.requestId != null) {
        final payload = <String, dynamic>{
          'applicant_name': _nameC.text.trim().isEmpty
              ? null
              : _nameC.text.trim(),
          'external_id': _extIdC.text.trim().isEmpty
              ? null
              : _extIdC.text.trim(),
        };
        // Jika sebelumnya status revisi, submit jadi prioritas antrian
        final isRevisi = _existing?.status == RequestStatus.revisionRequested;
        if (isRevisi) {
          payload.addAll({
            'status': 'waiting_review',
            'priority': true,
            'enqueued_at': DateTime.now().toIso8601String(),
          });
        }

        await Supabase.instance.client
            .from('requests')
            .update(payload)
            .eq('id', req.id);

        // catatan AE (kalau diisi saat edit)
        if (_noteC.text.trim().isNotEmpty) {
          await Supabase.instance.client.from('request_notes').insert({
            'request_id': req.id,
            'author_id': auth.user!.id,
            'role_snapshot': 'AE',
            'note': _noteC.text.trim(),
            // ⬇︎ FIX: harus 'note' agar lolos check constraint
            'action': 'note',
          });
        }
      }

      // 3) Upload semua file pending (jika ada)
      if (_pending.isNotEmpty) {
        for (final p in _pending) {
          await _medSvc.uploadMedia(
            requestId: req.id,
            file: p.file,
            type: p.type,
          );
        }
        _pending.clear();
        // sync kembali media agar tampil jika user kembali ke edit
        await mediaCtrl.loadMedia(req.id);
      }

      // 4) Selesai → kembali ke list & refresh
      if (!mounted) return;
      showSnack(context, 'Permohonan terkirim.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ================================ UI ========================================
  @override
  Widget build(BuildContext context) {
    final mediaCtrl = context.watch<MediaController>();
    final rid = widget.requestId ?? _existing?.id;
    final uploadedList = rid == null
        ? const <dynamic>[]
        : mediaCtrl.mediaOf(rid);

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Buat Permohonan' : 'Edit Permohonan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===================== FORM INPUT =====================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _form,
                child: Column(
                  children: [
                    // ID di atas sesuai mockup
                    TextFormField(
                      controller: _extIdC,
                      decoration: const InputDecoration(
                        labelText: 'ID Pemohon',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameC,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pemohon',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteC,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan AE (opsional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Hint validasi "salah satu wajib"
                    Builder(
                      builder: (_) {
                        final err = optionalButRequireOneOfTwo(
                          a: _nameC.text,
                          b: _extIdC.text,
                        );
                        return (err == null)
                            ? const SizedBox(height: 0)
                            : Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Isi salah satu: Nama Pemohon atau ID Pemohon',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              );
                      },
                    ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickMedia, // boleh pilih dulu
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Upload'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Kirim'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===================== PENDING PREVIEW =====================
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Akan diunggah (${_pending.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pending.map((p) {
                final isImg = p.type == MediaType.image;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isImg
                          ? Image.file(
                              p.file,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.play_circle_fill,
                                size: 40,
                              ),
                            ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: InkWell(
                        onTap: () => setState(() => _pending.remove(p)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            // const Text('Belum ada media terunggah.'),
          ],

          // ===================== UPLOADED PREVIEW =====================
          if (rid != null) ...[
            const SizedBox(height: 16),
            Text(
              'Sudah terunggah',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (mediaCtrl.loadingOf(rid))
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            // else if (uploadedList.isEmpty)
            //   const Text('Belum ada media terunggah.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: uploadedList.map((m) {
                  final isImg = m.isImage;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isImg
                            ? Image.network(
                                m.signedUrl ?? '',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Text('URL error'),
                                ),
                              )
                            : Container(
                                width: 120,
                                height: 120,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.play_circle_fill,
                                  size: 40,
                                ),
                              ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: () => mediaCtrl.delete(rid, m),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
