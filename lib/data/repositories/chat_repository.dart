import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';
import '../models/chat_message.dart';
import 'booking_repository.dart';
import 'notification_repository.dart';

/// Messages between a booking's customer and its assigned provider.
///
/// The booking document carries a summary (last message, who sent it, and
/// each side's read time) so booking lists can show unread markers without
/// opening every conversation.
class ChatRepository {
  ChatRepository(this._db, this._notifications);
  final FirebaseFirestore _db;
  final NotificationRepository _notifications;

  DocumentReference<Map<String, dynamic>> _booking(String id) =>
      _db.collection('bookings').doc(id);

  CollectionReference<Map<String, dynamic>> _messages(String bookingId) =>
      _booking(bookingId).collection('messages');

  /// Oldest first. Sorted here so messages still waiting for their server
  /// timestamp stay at the bottom.
  Stream<List<ChatMessage>> watch(String bookingId) =>
      _messages(bookingId).snapshots().map((s) {
        final far = DateTime(9999);
        return s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => (a.createdAt ?? far).compareTo(b.createdAt ?? far));
      });

  Future<void> send({
    required String bookingId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final body = text.trim();
    if (body.isEmpty) throw BookingException('Type a message first.');
    if (body.length > ChatMessage.maxLength) {
      throw BookingException(
          'Keep messages under ${ChatMessage.maxLength} characters.');
    }
    final snap = await _booking(bookingId).get();
    final b = Booking.fromMap(snap.id, snap.data()!);
    if (!b.isParticipant(senderId)) {
      throw BookingException('You are not part of this booking.');
    }
    if (!b.canChat) {
      throw BookingException(b.hasChat
          ? 'This booking is closed, so the chat is read-only.'
          : 'You can message once a cleaner accepts.');
    }

    final senderIsCustomer = senderId == b.customerId;
    final recipient = senderIsCustomer ? b.providerId! : b.customerId;
    // One notification per burst: skip it if the recipient already has
    // unread messages here.
    final alreadyUnread = b.hasUnreadFor(recipient);

    final batch = _db.batch()
      ..set(_messages(bookingId).doc(),
          ChatMessage.newDoc(
              senderId: senderId, senderName: senderName, text: body))
      ..update(_booking(bookingId), {
        'lastMessageText': body,
        'lastMessageBy': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        senderIsCustomer ? 'customerReadAt' : 'providerReadAt':
            FieldValue.serverTimestamp(),
      });
    await batch.commit();

    if (!alreadyUnread) {
      await _notifications.notify(
        userId: recipient,
        title: 'Message from $senderName',
        body: body.length > 80 ? '${body.substring(0, 80)}…' : body,
        bookingId: bookingId,
      );
    }
  }

  /// Marks the conversation read for [uid]. No-op if nothing is unread, so
  /// it's safe to call on every new message while the chat is open.
  Future<void> markRead(Booking b, String uid) async {
    if (!b.hasUnreadFor(uid)) return;
    await _booking(b.id).update({
      uid == b.customerId ? 'customerReadAt' : 'providerReadAt':
          FieldValue.serverTimestamp(),
    });
  }
}
