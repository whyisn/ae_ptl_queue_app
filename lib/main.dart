import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'core/supabase_client.dart';

import 'repositories/auth_repository.dart';
import 'repositories/requests_repository.dart';

import 'services/auth_service.dart';

import 'state/auth_provider.dart';
import 'state/request_provider.dart';
import 'state/media_provider.dart';

import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pakai helper milikmu (sudah ada di lib/core/supabase_client.dart)
  await initSupabase();

  // Repository
  final requestsRepo = RequestsRepository(Supabase.instance.client);
  final authRepo = AuthRepository(AuthService());

  // Providers
  final auth = AuthController(authRepo);
  final requests = RequestController(requestsRepo);
  final media = MediaController(requestsRepo);

  // Router aplikasi kamu butuh auth/requests/media (sudah ada kelas AppRouter di project)
  final router = AppRouter(auth: auth, requests: requests, media: media);

  runApp(
    _RootApp(auth: auth, requests: requests, media: media, router: router),
  );
}

/// Widget root, wiring Provider + MaterialApp.router
class _RootApp extends StatelessWidget {
  final AuthController auth;
  final RequestController requests;
  final MediaController media;
  final AppRouter router;

  const _RootApp({
    super.key,
    required this.auth,
    required this.requests,
    required this.media,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<RequestController>.value(value: requests),
        ChangeNotifierProvider<MediaController>.value(value: media),
      ],
      child: MaterialApp.router(
        title: 'AE • PTL Queue',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: router.router,
      ),
    );
  }
}
