import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_utils.dart';

/// `bookings/{bookingId}/messages/{id}`: chat between the customer and the
/// provider assigned to a booking.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  static const maxLength = 1000;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) =>
      ChatMessage(
        id: id,
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        text: map['text'] as String? ?? '',
        createdAt: readDate(map['createdAt']),
      );

  static Map<String, dynamic> newDoc({
    required String senderId,
    required String senderName,
    required String text,
  }) =>
      {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
