import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../data/models/app_user.dart';
import '../data/models/enums.dart';
import '../data/models/provider_profile.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Who is signed in, their `users` document and, for providers, their live
/// `providers` document. The root of the app rebuilds from this.
class SessionController extends ChangeNotifier {
  SessionController(this.backend) {
    _authSub = backend.auth.uidChanges().listen(_onUid);
  }

  final Backend backend;
  StreamSubscription<String?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;
  StreamSubscription<ProviderProfile?>? _providerSub;

  SessionStatus status = SessionStatus.loading;
  AppUser? user;
  ProviderProfile? provider;
  String? _uid;

  String get uid => _uid!;
  bool get isReady =>
      status == SessionStatus.signedIn &&
      user != null &&
      (user!.role != UserRole.provider || provider != null);

  void _onUid(String? uid) {
    if (uid == _uid && status != SessionStatus.loading) return;
    _uid = uid;
    _userSub?.cancel();
    _providerSub?.cancel();
    _providerSub = null;
    user = null;
    provider = null;

    if (uid == null) {
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    status = SessionStatus.signedIn;
    notifyListeners();

    _userSub = backend.users.watch(uid).listen((u) {
      user = u;
      if (u?.role == UserRole.provider && _providerSub == null) {
        _providerSub = backend.providers.watch(uid).listen((p) {
          provider = p;
          notifyListeners();
        });
      }
      notifyListeners();
    });
  }

  Future<void> signOut() async {
    await _providerSub?.cancel();
    _providerSub = null;
    await backend.auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _providerSub?.cancel();
    super.dispose();
  }
}
