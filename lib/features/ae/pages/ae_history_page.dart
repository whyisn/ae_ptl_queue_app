import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;

import '../../../core/utils.dart';
import '../../../models/request_model.dart';
import '../../../state/auth_provider.dart';
import '../../../state/request_provider.dart';
import '../../shared/status_badge.dart';

class AEHistoryPage extends StatefulWidget {
  const AEHistoryPage({super.key});

  @override
  State<AEHistoryPage> createState() => _AEHistoryPageState();
}

class _AEHistoryPageState extends State<AEHistoryPage> {
  bool loading = true;
  String? error;
  List<RequestModel> items = [];
  String _q = '';
  final _debouncer = Debouncer(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    // _load();
    // Pastikan locale date siap (menghindari LocaleDataException).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initializeDateFormatting('id_ID');
      await _load();
    });
  }

  List<RequestModel> _filtered(List<RequestModel> src) {
    if (_q.trim().isEmpty) return src;
    final qq = _q.toLowerCase();
    return src.where((r) {
      final a = (r.applicantName ?? '').toLowerCase();
      final e = (r.externalId ?? '').toLowerCase();
      return a.contains(qq) || e.contains(qq);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final auth = context.read<AuthController>();
      final sb = Supabase.instance.client;
      final since = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();

      final rows = await sb
          .from('requests')
          .select()
          .eq('ae_id', auth.user!.id)
          .inFilter('status', ['approved', 'rejected'])
          .gte('closed_at', since)
          .order('closed_at', ascending: false);

      setState(() {
        items = rows.map<RequestModel>((m) => RequestModel.fromMap(m)).toList();
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resubmit(RequestModel r) async {
    final sb = Supabase.instance.client;
    try {
      await sb
          .from('requests')
          .update({
            'status': 'waiting_review',
            'priority': true,
            'enqueued_at': DateTime.now().toIso8601String(),
            'closed_at': null,
          })
          .eq('id', r.id);

      showSnack(context, 'Permohonan diajukan ulang (prioritas).');
      await _load();
    } catch (e) {
      showSnack(context, 'Gagal ajukan ulang: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered(items);
    final req = context.watch<RequestController>();
    final auth = context.watch<AuthController>();
    final highlighted = req.globallyReviewed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histori Permohonan (7 hari)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              onChanged: (t) => _debouncer.run(() => setState(() => _q = t)),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari Nama atau ID Pemohon',
              ),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
          ? Center(child: Text(error!))
          : list.isEmpty
          ? const Center(child: Text('Tidak ada histori.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final r = list[i];
                  final isApproved = r.status == RequestStatus.approved;
                  return Card(
                    child: ListTile(
                      title: Text(r.displayApplicant),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            isApproved ? 'Diterima ✅' : 'Ditolak ❌',
                            style: TextStyle(
                              color: isApproved ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (r.closedAt != null)
                            Text('Selesai: ${formatDateTime(r.closedAt)}'),
                        ],
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => _resubmit(r),
                        child: const Text('Ajukan Ulang'),
                      ),
                    ),
                  );
                },
              ),
            ),

      // Banner "Sedang Direview" juga tampil di History
      bottomNavigationBar: (highlighted != null)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _GlobalReviewBar(
                  title: highlighted.displayApplicant,
                  subtitle:
                      'Diajukan oleh: ${highlighted.aeName ?? (auth.user?.email ?? 'Saya')}',
                ),
              ),
            )
          : null,
    );
  }
}

class _GlobalReviewBar extends StatelessWidget {
  final String title;
  final String subtitle;
  const _GlobalReviewBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76, maxHeight: 104),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const _GreenDot(),
              const SizedBox(width: 8),
              const StatusBadge(status: 'sedang_direview'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreenDot extends StatelessWidget {
  const _GreenDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
      ),
    );
  }
}
