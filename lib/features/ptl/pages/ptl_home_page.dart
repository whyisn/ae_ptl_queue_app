import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils.dart';
import '../../../state/auth_provider.dart';
import '../../../state/request_provider.dart';
import '../widgets/ptl_search_bar.dart';
import '../widgets/ptl_request_tile.dart';

class PTLHomePage extends StatefulWidget {
  const PTLHomePage({super.key});

  @override
  State<PTLHomePage> createState() => _PTLHomePageState();
}

class _PTLHomePageState extends State<PTLHomePage> {
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
        await req.loadPTLQueueByRsl(user.rslId); // pakai RSL bila ada
        if (user.rslId != null && user.rslId!.isNotEmpty) {
          req.startRealtimeForPTL(rslId: user.rslId!);
        }
      } else {
        await req.loadPTLQueue(); // fallback
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final req = context.watch<RequestController>();

    final items = req.ptlQueue.where((r) {
      if (_q.trim().isEmpty) return true;
      final qq = _q.toLowerCase();
      final a = (r.applicantName ?? '').toLowerCase();
      final e = (r.externalId ?? '').toLowerCase();
      return a.contains(qq) || e.contains(qq);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrian Review PTL'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async {
              final user = context.read<AuthController>().user;
              if (user != null) {
                await context.read<RequestController>().loadPTLQueueByRsl(
                  user.rslId,
                );
              } else {
                await context.read<RequestController>().loadPTLQueue();
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
            child: PTLSearchBar(
              hintText: 'Cari Nama atau ID Pemohon',
              onChanged: (t) => _debouncer.run(() => setState(() => _q = t)),
            ),
          ),
        ),
      ),
      body: req.loadingPTL
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                final user = context.read<AuthController>().user;
                if (user != null) {
                  await req.loadPTLQueueByRsl(user.rslId);
                } else {
                  await req.loadPTLQueue();
                }
              },
              // Pastikan tetap "scrollable" saat kosong agar bisa ditarik untuk refresh
              child: items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 240),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Belum ada antrian yang menunggu review.',
                            ),
                          ),
                        ),
                        SizedBox(height: 520),
                      ],
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final r = items[i];
                        return PTLRequestTile(
                          data: r,
                          onTap: () async {
                            final changed = await context.push<bool>(
                              '/ptl/detail/${r.id}',
                            );
                            if (changed == true && mounted) {
                              final u = context.read<AuthController>().user;
                              if (u != null) {
                                await context
                                    .read<RequestController>()
                                    .loadPTLQueueByRsl(u.rslId);
                              } else {
                                await context
                                    .read<RequestController>()
                                    .loadPTLQueue();
                              }
                            }
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
