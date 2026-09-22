import 'package:cloud_firestore/cloud_firestore.dart';

import 'address.dart';
import 'enums.dart';
import 'firestore_utils.dart';

/// `bookings/{id}`.
///
/// Lifecycle:
///   pending ─accept→ accepted ─start→ inProgress ─finish→ awaitingConfirmation
///     └─confirm (customer)→ completed
///   pending / accepted ─cancel→ cancelled
///
/// A booking is either sent to one provider the customer chose
/// ([requestedProviderId]) or broadcast to every approved provider whose
/// service areas cover [barangayCode] and whose tier passes [tierFilter].
class Booking {
  const Booking({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone = '',
    this.providerId,
    this.providerName,
    this.providerTier,
    this.requestedProviderId,
    this.tierFilter = TierFilter.any,
    required this.serviceType,
    required this.homeSize,
    required this.scheduledDate,
    required this.timeSlot,
    required this.address,
    this.notes = '',
    required this.estimateMin,
    required this.estimateMax,
    this.price,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentRef,
    this.commissionRate,
    this.commissionAmount,
    this.providerShare,
    this.status = BookingStatus.pending,
    this.declinedBy = const [],
    this.customerRated = false,
    this.providerRated = false,
    this.cancelledBy,
    this.cancelReason,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.planId,
    this.recurrence = Recurrence.none,
    this.visitNumber = 1,
    this.totalVisits = 1,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;

  final String? providerId;
  final String? providerName;
  final ProviderTier? providerTier;
  final String? requestedProviderId;
  final TierFilter tierFilter;

  final ServiceType serviceType;
  final HomeSize homeSize;
  final DateTime scheduledDate;
  final String timeSlot;
  final Address address;
  final String notes;

  /// Shown to the customer before a provider is assigned.
  final double estimateMin;
  final double estimateMax;

  /// Fixed when a provider accepts, from that provider's rate.
  final double? price;

  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentRef;
  final double? commissionRate;
  final double? commissionAmount;
  final double? providerShare;

  final BookingStatus status;
  final List<String> declinedBy;
  final bool customerRated;
  final bool providerRated;
  final String? cancelledBy;
  final String? cancelReason;

  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  /// Recurring plan this visit belongs to, if any.
  final String? planId;
  final Recurrence recurrence;
  final int visitNumber;
  final int totalVisits;

  bool get isRecurring => planId != null;

  String get barangayCode => address.barangay.code;
  bool get isDirect => requestedProviderId != null;
  double get displayPrice => price ?? estimateMin;

  /// In-app payments must be held before the provider can start.
  bool get readyToStart =>
      status == BookingStatus.accepted &&
      (paymentMethod == PaymentMethod.cash ||
          paymentStatus == PaymentStatus.held);

  factory Booking.fromMap(String id, Map<String, dynamic> map) => Booking(
        id: id,
        customerId: map['customerId'] as String? ?? '',
        customerName: map['customerName'] as String? ?? '',
        customerPhone: map['customerPhone'] as String? ?? '',
        providerId: map['providerId'] as String?,
        providerName: map['providerName'] as String?,
        providerTier: map['providerTier'] == null
            ? null
            : enumByName(
                ProviderTier.values, map['providerTier'], ProviderTier.individual),
        requestedProviderId: map['requestedProviderId'] as String?,
        tierFilter:
            enumByName(TierFilter.values, map['tierFilter'], TierFilter.any),
        serviceType: enumByName(
            ServiceType.values, map['serviceType'], ServiceType.regular),
        homeSize: enumByName(HomeSize.values, map['homeSize'], HomeSize.studio),
        scheduledDate: readDate(map['scheduledDate']) ?? DateTime.now(),
        timeSlot: map['timeSlot'] as String? ?? '',
        address: Address.fromMap(
            Map<String, dynamic>.from(map['address'] as Map? ?? const {})),
        notes: map['notes'] as String? ?? '',
        estimateMin: readDouble(map['estimateMin']),
        estimateMax: readDouble(map['estimateMax']),
        price: map['price'] == null ? null : readDouble(map['price']),
        paymentMethod: enumByName(
            PaymentMethod.values, map['paymentMethod'], PaymentMethod.cash),
        paymentStatus: enumByName(
            PaymentStatus.values, map['paymentStatus'], PaymentStatus.unpaid),
        paymentRef: map['paymentRef'] as String?,
        commissionRate: map['commissionRate'] == null
            ? null
            : readDouble(map['commissionRate']),
        commissionAmount: map['commissionAmount'] == null
            ? null
            : readDouble(map['commissionAmount']),
        providerShare: map['providerShare'] == null
            ? null
            : readDouble(map['providerShare']),
        status: enumByName(
            BookingStatus.values, map['status'], BookingStatus.pending),
        declinedBy: readStringList(map['declinedBy']),
        customerRated: map['customerRated'] as bool? ?? false,
        providerRated: map['providerRated'] as bool? ?? false,
        cancelledBy: map['cancelledBy'] as String?,
        cancelReason: map['cancelReason'] as String?,
        createdAt: readDate(map['createdAt']),
        acceptedAt: readDate(map['acceptedAt']),
        completedAt: readDate(map['completedAt']),
        planId: map['planId'] as String?,
        recurrence: enumByName(
            Recurrence.values, map['recurrence'], Recurrence.none),
        visitNumber: readInt(map['visitNumber'], 1),
        totalVisits: readInt(map['totalVisits'], 1),
      );

  /// The document written when a customer submits a request.
  Map<String, dynamic> toNewDocMap() => {
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'providerId': null,
        'providerName': null,
        'providerTier': null,
        'requestedProviderId': requestedProviderId,
        'tierFilter': tierFilter.name,
        'serviceType': serviceType.name,
        'homeSize': homeSize.name,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'timeSlot': timeSlot,
        'address': address.toMap(),
        'barangayCode': barangayCode,
        'notes': notes,
        'estimateMin': estimateMin,
        'estimateMax': estimateMax,
        'price': null,
        'paymentMethod': paymentMethod.name,
        'paymentStatus': PaymentStatus.unpaid.name,
        'status': BookingStatus.pending.name,
        'declinedBy': <String>[],
        'customerRated': false,
        'providerRated': false,
        'createdAt': FieldValue.serverTimestamp(),
        'planId': planId,
        'recurrence': recurrence.name,
        'visitNumber': visitNumber,
        'totalVisits': totalVisits,
      };

  /// The next visit of this booking's plan: same provider, slot, address and
  /// price, already accepted, on [date].
  Map<String, dynamic> nextVisitDoc(DateTime date, int visitNumber) => {
        ...toNewDocMap(),
        'providerId': providerId,
        'providerName': providerName,
        'providerTier': providerTier?.name,
        'requestedProviderId': providerId,
        'scheduledDate': Timestamp.fromDate(date),
        'estimateMin': price,
        'estimateMax': price,
        'price': price,
        'commissionRate': commissionRate,
        'commissionAmount': commissionAmount,
        'providerShare': providerShare,
        'status': BookingStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
        'visitNumber': visitNumber,
      };
}
