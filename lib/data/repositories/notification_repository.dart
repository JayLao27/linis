import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  Future<void> notify({
    required String userId,
    required String title,
    required String body,
    String? bookingId,
  }) =>
      _col.add(AppNotification.newDoc(
          userId: userId, title: title, body: body, bookingId: bookingId));

  Future<void> notifyMany({
    required Iterable<String> userIds,
    required String title,
    required String body,
    String? bookingId,
  }) async {
    final batch = _db.batch();
    for (final uid in userIds) {
      batch.set(
          _col.doc(),
          AppNotification.newDoc(
              userId: uid, title: title, body: body, bookingId: bookingId));
    }
    await batch.commit();
  }

  Stream<List<AppNotification>> watch(String userId) => _col
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => AppNotification.fromMap(d.id, d.data())).toList());

  Stream<int> watchUnreadCount(String userId) => _col
      .where('userId', isEqualTo: userId)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.size);

  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  Future<void> markAllRead(String userId) async {
    final unread = await _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}
