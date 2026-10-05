import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The details Google gives us about the person who signed in.
class GoogleProfile {
  const GoogleProfile({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
}

/// Email/password and Google sign-in. Profile data lives in Firestore
/// (`users/{uid}`); this only knows about credentials and the signed-in uid.
abstract class AuthRepository {
  Stream<String?> uidChanges();
  String? get currentUid;
  Future<String> signIn(String email, String password);
  Future<String> register(String email, String password);

  /// Lets the user pick a Google account. Returns null if they cancel.
  Future<GoogleProfile?> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;

  /// Makes sure Google sign-in is only set up once (phones only).
  Future<void>? _googleReady;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<String> signIn(String email, String password) => _guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
            email: email.trim(), password: password);
        return cred.user!.uid;
      });

  @override
  Future<String> register(String email, String password) => _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        return cred.user!.uid;
      });

  @override
  Future<GoogleProfile?> signInWithGoogle() => _guard(() async {
        final cred = kIsWeb ? await _googlePopup() : await _googleNative();
        final user = cred?.user;
        if (user == null) return null;
        return GoogleProfile(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          photoUrl: user.photoURL,
        );
      });

  /// On web, Firebase opens the Google sign-in window.
  Future<UserCredential?> _googlePopup() async {
    try {
      return await _auth.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (_popupClosedCodes.contains(e.code)) return null;
      rethrow;
    }
  }

  /// On Android and iOS, Google gives us a token and Firebase uses it to
  /// log the user in.
  Future<UserCredential?> _googleNative() async {
    final google = GoogleSignIn.instance;
    await (_googleReady ??= google.initialize(
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    ));
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException(
          'Google sign-in failed. ${e.description ?? 'Please try again.'}');
    }
    return _auth.signInWithCredential(GoogleAuthProvider.credential(
        idToken: account.authentication.idToken));
  }

  static const _popupClosedCodes = {
    'popup-closed-by-user',
    'cancelled-popup-request',
  };

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() async {
    // Also sign out of Google, so the user can pick an account next time.
    if (_googleReady != null) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Incorrect email or password.',
        'email-already-in-use' => 'An account already uses that email.',
        'account-exists-with-different-credential' =>
          'That email already has a password login. Log in with your password.',
        'popup-blocked' => 'Allow pop-ups for this site, then try again.',
        'weak-password' => 'Use a password with at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Try again in a minute.',
        'network-request-failed' => 'No internet connection.',
        _ => e.message ?? 'Sign-in failed.',
      });
    }
  }
}

/// In-memory accounts for the demo backend. Resets when the app restarts.
class DemoAuthRepository implements AuthRepository {
  final Map<String, ({String uid, String password})> _accounts = {};
  final _controller = StreamController<String?>.broadcast();
  String? _current;
  int _nextId = 1;

  /// The sample Google account used in demo mode.
  static const googleProfile = GoogleProfile(
    uid: 'demo-google',
    email: 'juan.delacruz@gmail.com',
    name: 'Juan Dela Cruz',
  );

  /// Used by the demo seed to create accounts with known uids.
  void addAccount(String email, String password, String uid) =>
      _accounts[email.toLowerCase()] = (uid: uid, password: password);

  @override
  Stream<String?> uidChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  String? get currentUid => _current;

  @override
  Future<String> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final acct = _accounts[email.trim().toLowerCase()];
    if (acct == null || acct.password != password) {
      throw AuthException('Incorrect email or password.');
    }
    _set(acct.uid);
    return acct.uid;
  }

  @override
  Future<String> register(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final key = email.trim().toLowerCase();
    if (!key.contains('@')) throw AuthException('That email address is not valid.');
    if (_accounts.containsKey(key)) {
      throw AuthException('An account already uses that email.');
    }
    if (password.length < 6) {
      throw AuthException('Use a password with at least 6 characters.');
    }
    final uid = 'demo-user-${_nextId++}';
    _accounts[key] = (uid: uid, password: password);
    _set(uid);
    return uid;
  }

  /// Demo mode has no real Google sign-in, so this always uses
  /// [googleProfile].
  @override
  Future<GoogleProfile?> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _set(googleProfile.uid);
    return googleProfile;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!_accounts.containsKey(email.trim().toLowerCase())) {
      throw AuthException('No account uses that email.');
    }
  }

  @override
  Future<void> signOut() async => _set(null);

  void _set(String? uid) {
    _current = uid;
    _controller.add(uid);
  }
}
