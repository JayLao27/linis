import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/enums.dart';

class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<void> create({
    required String uid,
    required UserRole role,
    required String fullName,
    required String email,
    required String phone,
  }) =>
      _users.doc(uid).set(AppUser(
            uid: uid,
            role: role,
            fullName: fullName.trim(),
            email: email.trim(),
            phone: phone.trim(),
          ).toMap());

  Stream<AppUser?> watch(String uid) => _users.doc(uid).snapshots().map(
      (s) => s.exists ? AppUser.fromMap(s.id, s.data()!) : null);

  Future<AppUser?> get(String uid) async {
    final s = await _users.doc(uid).get();
    return s.exists ? AppUser.fromMap(s.id, s.data()!) : null;
  }

  Future<void> updateProfile(
    String uid, {
    String? fullName,
    String? phone,
    String? photoUrl,
  }) =>
      _users.doc(uid).update({
        'fullName': ?fullName?.trim(),
        'phone': ?phone?.trim(),
        'photoUrl': ?photoUrl,
      });
}
