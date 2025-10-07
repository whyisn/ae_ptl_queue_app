import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  await initSupabase();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final AuthController? _auth;
  final RequestController? _requests;
  final MediaController? _media;
  final AppRouter? _router;

  const MyApp({
    super.key,
    AuthController? auth,
    RequestController? requests,
    MediaController? media,
    AppRouter? router,
  }) : _auth = auth,
       _requests = requests,
       _media = media,
       _router = router;

  @override
  Widget build(BuildContext context) {
    // Default instances (agar widget_test bawaan Flutter tetap jalan)
    final auth = _auth ?? AuthController(AuthRepository(AuthService()));
    final reqRepo = RequestsRepository();
    final requests = _requests ?? RequestController(reqRepo);
    final media = _media ?? MediaController(reqRepo);
    final router =
        _router ?? AppRouter(auth: auth, requests: requests, media: media);

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
