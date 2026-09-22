import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_utils.dart';

enum ReviewDirection { customerToProvider, providerToCustomer }

/// `reviews/{bookingId}_{direction}`. The id makes a second review of the same
/// booking in the same direction impossible.
class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.direction,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.rating,
    this.comment = '',
    this.createdAt,
  });

  final String id;
  final String bookingId;
  final ReviewDirection direction;
  final String fromUid;
  final String fromName;
  final String toUid;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  static String idFor(String bookingId, ReviewDirection direction) =>
      '${bookingId}_${direction.name}';

  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(
        id: id,
        bookingId: map['bookingId'] as String? ?? '',
        direction: map['direction'] == ReviewDirection.providerToCustomer.name
            ? ReviewDirection.providerToCustomer
            : ReviewDirection.customerToProvider,
        fromUid: map['fromUid'] as String? ?? '',
        fromName: map['fromName'] as String? ?? '',
        toUid: map['toUid'] as String? ?? '',
        rating: readInt(map['rating'], 5),
        comment: map['comment'] as String? ?? '',
        createdAt: readDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'direction': direction.name,
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
