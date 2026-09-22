import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_utils.dart';

/// `notifications/{id}`: in-app notifications, streamed live to the recipient.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.bookingId,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String? bookingId;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        userId: map['userId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        bookingId: map['bookingId'] as String?,
        read: map['read'] as bool? ?? false,
        createdAt: readDate(map['createdAt']),
      );

  static Map<String, dynamic> newDoc({
    required String userId,
    required String title,
    required String body,
    String? bookingId,
  }) =>
      {
        'userId': userId,
        'title': title,
        'body': body,
        'bookingId': bookingId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
