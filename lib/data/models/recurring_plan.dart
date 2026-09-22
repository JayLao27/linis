import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_utils.dart';

/// `plans/{id}`: a recurring cleaning with the same provider.
///
/// Visits are created one at a time: the first with the request, each next
/// one when the current visit is completed or skipped. [currentBookingId]
/// points at the visit in progress, so there is never more than one open
/// booking per plan.
class RecurringPlan {
  const RecurringPlan({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.providerId,
    this.providerName,
    required this.recurrence,
    required this.totalVisits,
    this.visitsCreated = 1,
    this.completedVisits = 0,
    this.active = true,
    this.currentBookingId,
    this.pricePerVisit,
    this.endedBy,
    this.createdAt,
  });

  final String id;
  final String customerId;
  final String customerName;

  /// Set when a provider accepts the first visit.
  final String? providerId;
  final String? providerName;
  final Recurrence recurrence;
  final int totalVisits;
  final int visitsCreated;
  final int completedVisits;
  final bool active;
  final String? currentBookingId;
  final double? pricePerVisit;

  /// Uid of whoever stopped the plan early; null if it ran its course.
  final String? endedBy;
  final DateTime? createdAt;

  bool get hasMoreVisits => visitsCreated < totalVisits;

  factory RecurringPlan.fromMap(String id, Map<String, dynamic> map) =>
      RecurringPlan(
        id: id,
        customerId: map['customerId'] as String? ?? '',
        customerName: map['customerName'] as String? ?? '',
        providerId: map['providerId'] as String?,
        providerName: map['providerName'] as String?,
        recurrence: enumByName(
            Recurrence.values, map['recurrence'], Recurrence.weekly),
        totalVisits: readInt(map['totalVisits'], 1),
        visitsCreated: readInt(map['visitsCreated'], 1),
        completedVisits: readInt(map['completedVisits']),
        active: map['active'] as bool? ?? false,
        currentBookingId: map['currentBookingId'] as String?,
        pricePerVisit: map['pricePerVisit'] == null
            ? null
            : readDouble(map['pricePerVisit']),
        endedBy: map['endedBy'] as String?,
        createdAt: readDate(map['createdAt']),
      );

  static Map<String, dynamic> newDoc({
    required String customerId,
    required String customerName,
    required Recurrence recurrence,
    required int totalVisits,
    required String firstBookingId,
  }) =>
      {
        'customerId': customerId,
        'customerName': customerName,
        'providerId': null,
        'providerName': null,
        'recurrence': recurrence.name,
        'totalVisits': totalVisits,
        'visitsCreated': 1,
        'completedVisits': 0,
        'active': true,
        'currentBookingId': firstBookingId,
        'pricePerVisit': null,
        'endedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// The visit dates after [from], for previews.
  List<DateTime> upcomingDates(DateTime from, {int max = 3}) {
    final remaining = (totalVisits - visitsCreated).clamp(0, max);
    return [
      for (var i = 1; i <= remaining; i++)
        from.add(Duration(days: recurrence.intervalDays * i)),
    ];
  }
}
