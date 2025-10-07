import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils.dart';
import '../../../models/request_model.dart';
import '../../../state/auth_provider.dart';

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
    _load();
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
      final since =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

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
      body:
          loading
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
    );
  }
}
