import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils.dart';
import '../../../models/request_model.dart';
import '../../../state/auth_provider.dart';
import '../../../state/request_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthController>();
      final req = context.read<RequestController>();
      final user = auth.user;
      if (user != null) {
        debugPrint('>>> A. AE ID aplikasi: ${user.id}');
        // load dengan awareness RSL (akan pakai fetchMyRequestsByRsl bila rslId ada)
        await req.loadMyRequestsForUser(user);
        // AE juga muat PTL queue supaya banner global konsisten
        await req.loadPTLQueueByRsl(user.rslId);
        // nyalakan realtime bila rslId tersedia
        if (user.rslId != null && user.rslId!.isNotEmpty) {
          req.startRealtimeForAE(aeId: user.id, rslId: user.rslId!);
        }
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

    // RequestModel? highlighted;
    // for (final r in list) {
    //   if (r.isBeingReviewed) {
    //     highlighted = r;
    //     break;
    //   }
    // }

    // Banner mengambil dari PTL queue (global), bukan list milik AE
    final highlighted = req.globallyReviewed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permohonan Saya'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () => context.push('/ae/history'),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              if (auth.user != null) {
                await req.loadMyRequestsForUser(auth.user!);
                await req.loadPTLQueueByRsl(auth.user!.rslId);
              }
            },
            icon: const Icon(Icons.refresh),
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
      body: req.loadingMy
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
                  await req.loadMyRequestsForUser(auth.user!);
                }
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (_, i) {
                  final item = list[i];
                  final showDelete =
                      item.status != RequestStatus.revisionRequested;

                  // HANYA queuePos global (jika null → '-'), TANPA fallback index
                  final queueNumberText = (item.queuePos != null)
                      ? '${item.queuePos}'
                      : '-';

                  return InkWell(
                    onTap: () => context.push('/ae/detail/${item.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kiri: Antrian
                          SizedBox(
                            width: 52,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  queueNumberText,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Antrian',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                if (item.priority)
                                  Text(
                                    'Prioritas',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tengah: Detail
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayApplicant,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Satu badge status saja
                                Row(
                                  children: [
                                    StatusBadge(
                                      status: item.isBeingReviewed
                                          ? 'sedang_direview'
                                          : requestStatusToString(item.status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Catt dari PTL terakhir
                                Text(
                                  'Catt: ${item.aeNoteLast?.trim().isNotEmpty == true ? item.aeNoteLast!.trim() : '-'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Kanan: Aksi
                          Column(
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () async {
                                  final ok = await context.push(
                                    '/ae/form?id=${item.id}',
                                  );
                                  if (ok == true && auth.user != null) {
                                    await req.loadMyRequestsForUser(auth.user!);
                                  }
                                },
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

      // // Kartu highlight "Sedang direview"
      // bottomNavigationBar: (highlighted != null)
      //     ? SafeArea(
      //         top: false,
      //         child: Padding(
      //           padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      //           child: Container(
      //             padding: const EdgeInsets.all(16),
      //             decoration: BoxDecoration(
      //               color: Theme.of(context).colorScheme.surface,
      //               borderRadius: BorderRadius.circular(16),
      //               boxShadow: const [
      //                 BoxShadow(
      //                   blurRadius: 12,
      //                   offset: Offset(0, 4),
      //                   color: Color(0x14000000),
      //                 ),
      //               ],
      //             ),
      //             child: Row(
      //               children: [
      //                 Container(
      //                   width: 10,
      //                   height: 10,
      //                   margin: const EdgeInsets.only(right: 8, top: 2),
      //                   decoration: const BoxDecoration(
      //                     shape: BoxShape.circle,
      //                     color: Colors.green,
      //                   ),
      //                 ),
      //                 Expanded(
      //                   child: Column(
      //                     crossAxisAlignment: CrossAxisAlignment.start,
      //                     children: [
      //                       Text(
      //                         'Sedang direview',
      //                         style: TextStyle(
      //                           fontSize: 12,
      //                           color: Colors.grey.shade700,
      //                           fontWeight: FontWeight.w600,
      //                         ),
      //                       ),
      //                       const SizedBox(height: 4),
      //                       Text(
      //                         highlighted!.displayApplicant,
      //                         style: const TextStyle(
      //                           fontSize: 16,
      //                           fontWeight: FontWeight.w700,
      //                         ),
      //                       ),
      //                       const SizedBox(height: 2),
      //                       Text(
      //                         'Diajukan oleh: ${highlighted!.aeName ?? (auth.user?.email ?? 'Saya')}',
      //                         style: TextStyle(
      //                           fontSize: 12,
      //                           color: Colors.grey.shade600,
      //                         ),
      //                       ),
      //                     ],
      //                   ),
      //                 ),
      //                 const SizedBox(width: 8),
      //                 FloatingActionButton.small(
      //                   heroTag: 'fab-mini',
      //                   onPressed: () async {
      //                     final ok = await context.push('/ae/form');
      //                     if (ok == true && auth.user != null) {
      //                       await req.loadMyRequestsForUser(auth.user!);
      //                     }
      //                   },
      //                   child: const Icon(Icons.add),
      //                 ),
      //               ],
      //             ),
      //           ),
      //         ),
      //       )
      //     : null,
      bottomNavigationBar: (highlighted != null)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _ReviewInProgressBar(
                  title: highlighted!.displayApplicant,
                  subtitle:
                      'Diajukan oleh: ${highlighted!.aeName ?? (auth.user?.email ?? 'Saya')}',
                  onAdd: () async {
                    final ok = await context.push('/ae/form');
                    if (ok == true && auth.user != null) {
                      await req.loadMyRequestsForUser(auth.user!);
                    }
                  },
                ),
              ),
            )
          : null,

      floatingActionButton: (highlighted == null)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await context.push('/ae/form');
                if (ok == true && auth.user != null) {
                  await req.loadMyRequestsForUser(auth.user!);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Buat Permohonan'),
            )
          : null,
    );
  }
}

/// Bar “Sedang Direview” yang tampil di bawah (tinggi terbatas & konsisten gaya).
class _ReviewInProgressBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAdd;
  const _ReviewInProgressBar({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

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
              // indikator + badge sesuai komponen shared
              const _GreenDot(),
              const SizedBox(width: 8),
              const StatusBadge(status: 'sedang_direview'),
              const SizedBox(width: 10),
              // teks
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
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: 'fab-mini',
                onPressed: onAdd,
                child: const Icon(Icons.add),
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
