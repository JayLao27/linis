import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';
import '../models/enums.dart';
import '../models/review.dart';
import 'booking_repository.dart';
import 'notification_repository.dart';

/// Two-way ratings after a completed job. The customer rates the provider
/// (`providers/{id}` average) and the provider rates the customer
/// (`users/{id}` average). Averages update in the same transaction as the
/// review, so profiles stream the new value straight away.
class ReviewRepository {
  ReviewRepository(this._db, this._notifications);
  final FirebaseFirestore _db;
  final NotificationRepository _notifications;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('reviews');

  Future<void> submit({
    required String bookingId,
    required ReviewDirection direction,
    required String fromUid,
    required String fromName,
    required int rating,
    String comment = '',
  }) async {
    if (rating < 1 || rating > 5) {
      throw BookingException('Pick between 1 and 5 stars.');
    }
    final byCustomer = direction == ReviewDirection.customerToProvider;

    final booking = await _db.runTransaction((tx) async {
      final bRef = _db.collection('bookings').doc(bookingId);
      final bSnap = await tx.get(bRef);
      final b = Booking.fromMap(bSnap.id, bSnap.data()!);
      if (b.status != BookingStatus.completed) {
        throw BookingException('You can rate once the job is completed.');
      }
      if (fromUid != (byCustomer ? b.customerId : b.providerId)) {
        throw BookingException('You were not part of this booking.');
      }
      if (byCustomer ? b.customerRated : b.providerRated) {
        throw BookingException('You already rated this booking.');
      }

      final toUid = byCustomer ? b.providerId! : b.customerId;
      final targetRef = _db
          .collection(byCustomer ? 'providers' : 'users')
          .doc(toUid);
      final target = await tx.get(targetRef);
      final data = target.data() ?? const {};
      final count = (data['ratingCount'] as num? ?? 0).toInt();
      final avg = (data['ratingAvg'] as num? ?? 0).toDouble();
      final newCount = count + 1;
      final newAvg = ((avg * count) + rating) / newCount;

      tx.set(
          _col.doc(Review.idFor(bookingId, direction)),
          Review(
            id: '',
            bookingId: bookingId,
            direction: direction,
            fromUid: fromUid,
            fromName: fromName,
            toUid: toUid,
            rating: rating,
            comment: comment.trim(),
          ).toMap());
      tx.update(targetRef, {
        'ratingAvg': double.parse(newAvg.toStringAsFixed(2)),
        'ratingCount': newCount,
      });
      tx.update(bRef, {byCustomer ? 'customerRated' : 'providerRated': true});
      return b;
    });

    await _notifications.notify(
      userId: byCustomer ? booking.providerId! : booking.customerId,
      title: '$fromName rated you $rating★',
      body: comment.trim().isEmpty ? 'Thanks for a job well done.' : comment.trim(),
      bookingId: bookingId,
    );
  }

  /// Written reviews about [uid], newest first.
  Stream<List<Review>> watchFor(String uid) => _col
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Review.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));
}
