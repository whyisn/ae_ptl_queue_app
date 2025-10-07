import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/request_provider.dart';
import '../state/media_provider.dart';

// AUTH
import '../features/auth/login_page.dart';

// AE
import '../features/ae/pages/ae_home_page.dart';
import '../features/ae/pages/ae_form_page.dart';
import '../features/ae/pages/ae_detail_page.dart';
import '../features/ae/pages/ae_history_page.dart';

// PTL
import '../features/ptl/pages/ptl_home_page.dart';
import '../features/ptl/pages/ptl_detail_page.dart';

class AppRouter {
  final AuthController auth;
  final RequestController requests;
  final MediaController media;

  AppRouter({required this.auth, required this.requests, required this.media});

  late final GoRouter router = GoRouter(
    refreshListenable: auth,
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final isLoading = auth.loading;
      final path = state.uri.path;
      final isLogin = path == '/login';

      if (isLoading) return null;

      if (!loggedIn) {
        return isLogin ? null : '/login';
      }

      if (isLogin) {
        return auth.isPTL ? '/ptl' : '/ae';
      }

      if (path.startsWith('/ptl') && !auth.isPTL) {
        return '/ae';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // AE
      GoRoute(
        path: '/ae',
        name: 'ae_home',
        builder: (context, state) => const AEHomePage(),
        routes: [
          GoRoute(
            path: 'form',
            name: 'ae_form',
            builder: (context, state) {
              final id = state.uri.queryParameters['id'];
              return AEFormPage(requestId: id);
            },
          ),
          GoRoute(
            path: 'detail/:id',
            name: 'ae_detail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AEDetailPage(requestId: id);
            },
          ),
          GoRoute(
            path: 'history',
            name: 'ae_history',
            builder: (context, state) => const AEHistoryPage(),
          ),
        ],
      ),

      // PTL
      GoRoute(
        path: '/ptl',
        name: 'ptl_home',
        builder: (context, state) => const PTLHomePage(),
        routes: [
          GoRoute(
            path: 'detail/:id',
            name: 'ptl_detail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return PTLDetailPage(requestId: id);
            },
          ),
        ],
      ),

      // Fallback
      GoRoute(
        path: '/',
        builder: (context, state) {
          final a = context.read<AuthController>();
          if (!a.isLoggedIn) return const LoginPage();
          return a.isPTL ? const PTLHomePage() : const AEHomePage();
        },
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Terjadi kesalahan')),
          body: Center(child: Text(state.error?.toString() ?? 'Unknown error')),
        ),
  );
}
