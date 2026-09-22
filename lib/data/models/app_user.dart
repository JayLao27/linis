import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_utils.dart';

/// `users/{uid}`: every account, customer, provider or admin.
///
/// Customers are rated by providers after each job, so they carry a rating too.
class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.photoUrl,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.createdAt,
  });

  final String uid;
  final UserRole role;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final double ratingAvg;
  final int ratingCount;
  final DateTime? createdAt;

  String get firstName => fullName.split(' ').first;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        role: enumByName(UserRole.values, map['role'], UserRole.customer),
        fullName: map['fullName'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        photoUrl: map['photoUrl'] as String?,
        ratingAvg: readDouble(map['ratingAvg']),
        ratingCount: readInt(map['ratingCount']),
        createdAt: readDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
