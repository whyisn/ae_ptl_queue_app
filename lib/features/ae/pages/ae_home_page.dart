import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils.dart';
import '../../../models/request_model.dart';
import '../../../state/auth_provider.dart';
import '../../../state/request_provider.dart';
// import '../../shared/request_card.dart';
import '../../shared/status_badge.dart';
import '../widgets/ae_search_bar.dart';
import '../widgets/empty_state.dart';

class AEHomePage extends StatefulWidget {
  const AEHomePage({super.key});

  @override
  State<AEHomePage> createState() => _AEHomePageState();
}

class _AEHomePageState extends State<AEHomePage> {
  String _q = '';
  final _debouncer = Debouncer(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final req = context.read<RequestController>();
      if (auth.user != null) {
        req.loadMyRequests(auth.user!.id);
      }
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final req = context.watch<RequestController>();
    final list = _filtered(req.myRequests);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permohonan Saya'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () => context.push('/ae/history'),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: AESearchBar(
              hintText: 'Cari Nama atau ID Pemohon',
              onChanged: (t) => _debouncer.run(() => setState(() => _q = t)),
            ),
          ),
        ),
      ),
      body:
          req.loadingMy
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
              ? const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'Belum ada permohonan',
                subtitle: 'Tekan tombol tambah untuk membuat permohonan baru.',
              )
              : RefreshIndicator(
                onRefresh: () async {
                  if (auth.user != null) {
                    await req.loadMyRequests(auth.user!.id);
                  }
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final item = list[i];
                    final showDelete =
                        item.status != RequestStatus.revisionRequested;
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        onTap: () => context.push('/ae/detail/${item.id}'),
                        title: Text(item.displayApplicant),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            StatusBadge(
                              status:
                                  item.isBeingReviewed
                                      ? 'sedang_direview'
                                      : requestStatusToString(item.status),
                            ),
                            if (item.priority)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
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
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed:
                                  () => context.push('/ae/form?id=${item.id}'),
                              icon: const Icon(Icons.edit),
                            ),
                            if (showDelete)
                              IconButton(
                                tooltip: 'Hapus',
                                onPressed: () async {
                                  await req.deleteRequest(
                                    item.id,
                                    aeId: auth.user!.id,
                                  );
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ae/form'),
        icon: const Icon(Icons.add),
        label: const Text('Buat Permohonan'),
      ),
    );
  }
}
