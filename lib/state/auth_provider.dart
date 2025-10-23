import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository _repo;

  AuthController(this._repo) {
    _sub = _repo.onAuthStateChange().listen((event) async {
      switch (event.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.tokenRefreshed:
          await _loadCurrentUser();
          break;
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.passwordRecovery:
        default:
          _user = null;
          notifyListeners();
      }
    });

    _loadCurrentUser();
  }

  late final StreamSubscription<AuthState> _sub;

  AppUser? _user;
  AppUser? get user => _user;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool get isLoggedIn => _user != null;
  bool get isPTL => _user?.isPTL == true;

  Future<void> _loadCurrentUser() async {
    try {
      _loading = true;
      notifyListeners();
      _user = await _repo.currentUser();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool remember = false,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _repo.signIn(email, password);
      if (remember) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('remember_email', email);
      }
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repo.signOut();
    _user = null;
    notifyListeners();
  }

  Future<String?> getRememberedEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('remember_email');
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
