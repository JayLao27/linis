import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../models/booking.dart';
import '../models/enums.dart';
import '../models/ledger_entry.dart';
import '../models/provider_profile.dart';
import '../models/recurring_plan.dart';
import '../services/pricing_service.dart';
import 'notification_repository.dart';
import 'provider_repository.dart';

class BookingException implements Exception {
  BookingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Every booking state change goes through here, inside a transaction where
/// money or assignment is involved, so two providers can't accept the same
/// request and a job can't be paid out twice.
class BookingRepository {
  BookingRepository(
    this._db,
    this._providers,
    this._notifications, {
    this.pricing = const PricingService(),
  });

  final FirebaseFirestore _db;
  final ProviderRepository _providers;
  final NotificationRepository _notifications;
  final PricingService pricing;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('bookings');
  CollectionReference<Map<String, dynamic>> get _providerCol =>
      _db.collection('providers');
  CollectionReference<Map<String, dynamic>> get _ledger =>
      _db.collection('ledger');
  CollectionReference<Map<String, dynamic>> get _plans =>
      _db.collection('plans');

  Booking _fromSnap(DocumentSnapshot<Map<String, dynamic>> s) =>
      Booking.fromMap(s.id, s.data()!);

  List<Booking> _sorted(QuerySnapshot<Map<String, dynamic>> s,
          {bool bySchedule = false}) =>
      s.docs.map(_fromSnap).toList()
        ..sort((a, b) => bySchedule
            ? a.scheduledDate.compareTo(b.scheduledDate)
            : (b.createdAt ?? DateTime.now())
                .compareTo(a.createdAt ?? DateTime.now()));

  // ---------------------------------------------------------------- reads

  Stream<Booking?> watch(String id) =>
      _col.doc(id).snapshots().map((s) => s.exists ? _fromSnap(s) : null);

  Stream<RecurringPlan?> watchPlan(String planId) => _plans
      .doc(planId)
      .snapshots()
      .map((s) => s.exists ? RecurringPlan.fromMap(s.id, s.data()!) : null);

  Stream<List<Booking>> watchForCustomer(String uid) =>
      _col.where('customerId', isEqualTo: uid).snapshots().map(_sorted);

  Stream<List<Booking>> watchForProvider(String uid) => _col
      .where('providerId', isEqualTo: uid)
      .snapshots()
      .map((s) => _sorted(s, bySchedule: true));

  /// Open requests a provider can take: pending, in one of their barangays,
  /// allowed for their tier, for a service they offer, and either broadcast or
  /// addressed to them.
  Stream<List<Booking>> watchOpenRequests(ProviderProfile p) {
    if (p.serviceAreas.isEmpty) return Stream.value(const []);
    return _col
        .where('status', isEqualTo: BookingStatus.pending.name)
        .where('barangayCode',
            whereIn: p.serviceAreas.take(Business.maxServiceAreas).toList())
        .snapshots()
        .map((s) => _sorted(s, bySchedule: true)
            .where((b) =>
                (b.requestedProviderId == null ||
                    b.requestedProviderId == p.uid) &&
                b.tierFilter.allows(p.tier) &&
                p.offers(b.serviceType) &&
                !b.declinedBy.contains(p.uid))
            .toList());
  }

  // --------------------------------------------------------------- create

  /// Submits a request and notifies the providers who can see it.
  /// Returns the new booking id.
  Future<String> create(Booking draft) async {
    _validateDraft(draft);
    final ref = _col.doc();
    if (draft.recurrence.isRecurring) {
      final planRef = _plans.doc();
      await (_db.batch()
            ..set(ref, {
              ...draft.toNewDocMap(),
              'planId': planRef.id,
              'visitNumber': 1,
            })
            ..set(
                planRef,
                RecurringPlan.newDoc(
                  customerId: draft.customerId,
                  customerName: draft.customerName,
                  recurrence: draft.recurrence,
                  totalVisits: draft.totalVisits,
                  firstBookingId: ref.id,
                )))
          .commit();
    } else {
      await ref.set(draft.toNewDocMap());
    }

    final String title = draft.recurrence.isRecurring
        ? 'New ${draft.recurrence.label.toLowerCase()} plan request'
        : 'New ${draft.serviceType.label.toLowerCase()} request';
    final String body =
        '${draft.homeSize.label} in ${draft.address.barangay.name} on '
        '${formatDate(draft.scheduledDate)}, ${draft.timeSlot}.'
        '${draft.recurrence.isRecurring ? ' ${draft.totalVisits} visits, ${draft.serviceType.label.toLowerCase()}.' : ''}';
    if (draft.requestedProviderId != null) {
      await _notifications.notify(
          userId: draft.requestedProviderId!,
          title: title,
          body: 'A customer chose you. $body',
          bookingId: ref.id);
    } else {
      final matches = await _providers.matching(
          barangayCode: draft.barangayCode,
          service: draft.serviceType,
          tierFilter: draft.tierFilter);
      await _notifications.notifyMany(
          userIds: matches.map((p) => p.uid),
          title: title,
          body: body,
          bookingId: ref.id);
    }
    return ref.id;
  }

  void _validateDraft(Booking b) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    if (b.scheduledDate.isBefore(startOfToday)) {
      throw BookingException('Pick a date from today onward.');
    }
    if (b.address.barangay.code.isEmpty || b.address.street.trim().isEmpty) {
      throw BookingException('Add your complete address.');
    }
    if (b.timeSlot.isEmpty) throw BookingException('Pick a time.');
    if (b.recurrence.isRecurring &&
        !Business.planVisitOptions.contains(b.totalVisits)) {
      throw BookingException('Pick how many visits the plan should have.');
    }
    if (b.serviceType.companyOnly && b.tierFilter == TierFilter.individual) {
      throw BookingException(
          '${b.serviceType.label} is only offered by companies.');
    }
  }

  // ------------------------------------------------------ provider actions

  /// First provider to accept gets the job. The price is fixed from their
  /// rate at this moment, along with the commission split.
  Future<void> accept(String bookingId, String providerId) async {
    final booking = await _db.runTransaction((tx) async {
      final bSnap = await tx.get(_col.doc(bookingId));
      final pSnap = await tx.get(_providerCol.doc(providerId));
      if (!bSnap.exists || !pSnap.exists) {
        throw BookingException('This request no longer exists.');
      }
      final b = _fromSnap(bSnap);
      final p = ProviderProfile.fromMap(pSnap.id, pSnap.data()!);
      final planRef = b.planId == null ? null : _plans.doc(b.planId);

      if (b.status != BookingStatus.pending || b.providerId != null) {
        throw BookingException('Another provider already took this job.');
      }
      if (!p.isApproved) {
        throw BookingException('Your account is not verified yet.');
      }
      if (p.bookingsPaused) {
        throw BookingException('New bookings are paused until you settle '
            '${peso(p.unsettledCommission)} in commission.');
      }
      if (!p.covers(b.barangayCode) || !b.tierFilter.allows(p.tier)) {
        throw BookingException('This request is outside your service areas.');
      }
      if (b.requestedProviderId != null && b.requestedProviderId != providerId) {
        throw BookingException('This request was sent to another provider.');
      }

      // Accepting the first visit of a plan commits to every visit at this
      // discounted price.
      final price =
          pricing.quoteFor(p, b.serviceType, b.homeSize, b.recurrence);
      final split = pricing.split(price, p.tier);
      if (planRef != null) {
        tx.update(planRef, {
          'providerId': p.uid,
          'providerName': p.displayName,
          'pricePerVisit': price,
        });
      }
      tx.update(bSnap.reference, {
        'providerId': p.uid,
        'providerName': p.displayName,
        'providerTier': p.tier.name,
        'price': price,
        'commissionRate': split.rate,
        'commissionAmount': split.commission,
        'providerShare': split.providerShare,
        'status': BookingStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      return b;
    });

    final provider = await _providers.get(providerId);
    await _notifications.notify(
      userId: booking.customerId,
      title: '${provider?.displayName ?? 'A cleaner'} accepted your '
          '${booking.isRecurring ? '${booking.recurrence.label.toLowerCase()} plan' : 'booking'}',
      body: booking.paymentMethod == PaymentMethod.gcash
          ? 'Pay through GCash to lock in ${formatDate(booking.scheduledDate)}.'
          : 'See you on ${formatDate(booking.scheduledDate)}, ${booking.timeSlot}.',
      bookingId: bookingId,
    );
  }

  /// A direct request that is declined opens up to every matching provider
  /// instead of dying, so the customer doesn't have to start over.
  Future<void> decline(String bookingId, String providerId) async {
    final b = _fromSnap(await _col.doc(bookingId).get());
    await _col.doc(bookingId).update({
      'declinedBy': FieldValue.arrayUnion([providerId]),
      if (b.requestedProviderId == providerId) 'requestedProviderId': null,
    });
    if (b.requestedProviderId == providerId) {
      await _notifications.notify(
        userId: b.customerId,
        title: 'Your chosen cleaner is unavailable',
        body: 'We sent your request to other cleaners in '
            '${b.address.barangay.name}.',
        bookingId: bookingId,
      );
      final matches = await _providers.matching(
          barangayCode: b.barangayCode,
          service: b.serviceType,
          tierFilter: b.tierFilter);
      await _notifications.notifyMany(
        userIds: matches.map((p) => p.uid).where((id) => id != providerId),
        title: 'New ${b.serviceType.label.toLowerCase()} request',
        body: '${b.homeSize.label} in ${b.address.barangay.name} on '
            '${formatDate(b.scheduledDate)}.',
        bookingId: bookingId,
      );
    }
  }

  Future<void> start(String bookingId, String providerId) async {
    final b = await _transition(bookingId,
        actor: providerId,
        from: {BookingStatus.accepted},
        to: BookingStatus.inProgress,
        guard: (b) {
          if (!b.readyToStart) {
            throw BookingException(
                'Wait for the customer\'s GCash payment before starting.');
          }
        });
    await _notifications.notify(
        userId: b.customerId,
        title: 'Your cleaner has started',
        body: '${b.providerName} is now cleaning.',
        bookingId: bookingId);
  }

  Future<void> finish(String bookingId, String providerId) async {
    final b = await _transition(bookingId,
        actor: providerId,
        from: {BookingStatus.inProgress},
        to: BookingStatus.awaitingConfirmation);
    await _notifications.notify(
        userId: b.customerId,
        title: 'Job marked as done',
        body: b.paymentMethod == PaymentMethod.gcash
            ? 'Confirm the job to release payment to ${b.providerName}.'
            : 'Confirm the job once you have paid ${peso(b.displayPrice)} in cash.',
        bookingId: bookingId);
  }

  // ------------------------------------------------------ customer actions

  /// Records a successful GCash charge. The money stays held by Linis until
  /// the customer confirms the job.
  Future<void> recordGcashPayment(String bookingId, String reference) =>
      _db.runTransaction((tx) async {
        final snap = await tx.get(_col.doc(bookingId));
        final b = _fromSnap(snap);
        if (b.paymentMethod != PaymentMethod.gcash ||
            b.paymentStatus != PaymentStatus.unpaid) {
          throw BookingException('This booking is already paid.');
        }
        if (b.status != BookingStatus.accepted) {
          throw BookingException('You can pay once a cleaner accepts.');
        }
        tx.update(snap.reference, {
          'paymentStatus': PaymentStatus.held.name,
          'paymentRef': reference,
        });
      });

  /// Customer confirms the job is done. GCash money is released to the
  /// provider minus commission; for cash jobs the commission is added to what
  /// the provider owes, and bookings pause once that passes the cap.
  Future<void> confirmCompletion(String bookingId, String customerId) async {
    final result = await _db.runTransaction((tx) async {
      final bSnap = await tx.get(_col.doc(bookingId));
      final b = _fromSnap(bSnap);
      if (b.customerId != customerId) {
        throw BookingException('Only the customer can confirm this job.');
      }
      if (b.status != BookingStatus.awaitingConfirmation) {
        throw BookingException('The cleaner has not marked this job as done.');
      }
      final pRef = _providerCol.doc(b.providerId);
      final pSnap = await tx.get(pRef);
      final p = ProviderProfile.fromMap(pSnap.id, pSnap.data()!);
      final plan = await _readPlan(tx, b.planId);

      final commission = b.commissionAmount ?? 0;
      final share = b.providerShare ?? (b.displayPrice - commission);
      final isCash = b.paymentMethod == PaymentMethod.cash;

      tx.update(bSnap.reference, {
        'status': BookingStatus.completed.name,
        'paymentStatus': isCash
            ? PaymentStatus.cashCollected.name
            : PaymentStatus.released.name,
        'completedAt': FieldValue.serverTimestamp(),
      });
      tx.update(pRef, {
        'completedJobs': FieldValue.increment(1),
        'totalEarnings': FieldValue.increment(share),
        if (isCash) 'unsettledCommission': FieldValue.increment(commission),
      });
      tx.set(
          _ledger.doc(),
          LedgerEntry.newDoc(
            providerId: p.uid,
            type: isCash ? LedgerType.cashCommissionDue : LedgerType.gcashRelease,
            amount: share,
            commission: commission,
            bookingId: b.id,
            reference: b.paymentRef,
          ));
      final next = _advancePlan(tx, plan, b, completed: true);
      final owedAfter = p.unsettledCommission + (isCash ? commission : 0);
      return (
        booking: b,
        owedAfter: owedAfter,
        isCash: isCash,
        share: share,
        next: next,
      );
    });

    final b = result.booking;
    await _notifications.notify(
      userId: b.providerId!,
      title: 'Job completed',
      body: result.isCash
          ? '${b.customerName} confirmed the job. ${peso(b.commissionAmount ?? 0)} '
              'commission was added to your weekly settlement.'
          : '${peso(result.share)} was released to you for ${b.customerName}\'s job.',
      bookingId: b.id,
    );
    if (result.isCash && result.owedAfter >= Business.unsettledCommissionCap) {
      await _notifications.notify(
        userId: b.providerId!,
        title: 'New bookings paused',
        body: 'You owe ${peso(result.owedAfter)} in commission. Settle it to '
            'start receiving requests again.',
      );
    }
    await _notifyNextVisit(b, result.next);
  }

  /// Either side can cancel before work starts. Held GCash payments are
  /// refunded.
  ///
  /// For a plan visit this skips the visit and schedules the next one, unless
  /// [endPlan] is set, no provider has accepted the plan yet, or it was the
  /// last visit.
  Future<void> cancel(
    String bookingId,
    String byUid, {
    String reason = '',
    bool endPlan = false,
  }) async {
    final result = await _db.runTransaction((tx) async {
      final snap = await tx.get(_col.doc(bookingId));
      final b = _fromSnap(snap);
      final plan = await _readPlan(tx, b.planId);
      if (byUid != b.customerId && byUid != b.providerId) {
        throw BookingException('You cannot cancel this booking.');
      }
      if (b.status != BookingStatus.pending &&
          b.status != BookingStatus.accepted) {
        throw BookingException('Jobs that have started cannot be cancelled.');
      }
      tx.update(snap.reference, {
        'status': BookingStatus.cancelled.name,
        'cancelledBy': byUid,
        'cancelReason': reason,
        if (b.paymentStatus == PaymentStatus.held)
          'paymentStatus': PaymentStatus.refunded.name,
      });
      final next = endPlan || b.providerId == null
          ? _stopPlan(tx, plan, byUid)
          : _advancePlan(tx, plan, b, completed: false);
      return (booking: b, next: next);
    });

    final b = result.booking;
    await _notifyNextVisit(b, result.next, skipped: true);
    final byCustomer = byUid == b.customerId;
    final otherParty = byCustomer ? b.providerId : b.customerId;
    if (otherParty != null) {
      await _notifications.notify(
        userId: otherParty,
        title: 'Booking cancelled',
        body: byCustomer
            ? '${b.customerName} cancelled the ${formatDate(b.scheduledDate)} job.'
            : '${b.providerName} cancelled. '
                '${b.paymentStatus == PaymentStatus.held ? 'Your GCash payment will be refunded.' : 'You can book again anytime.'}',
        bookingId: b.id,
      );
    }
  }

  /// Stops a plan early. The open visit is cancelled (and refunded) unless the
  /// cleaner has already started it.
  Future<void> endPlan(String planId, String byUid) async {
    final plan = await _db.runTransaction((tx) async {
      final plan = await _readPlan(tx, planId);
      if (plan == null || !plan.active) {
        throw BookingException('This plan has already ended.');
      }
      if (byUid != plan.customerId && byUid != plan.providerId) {
        throw BookingException('You are not part of this plan.');
      }
      final currentRef =
          plan.currentBookingId == null ? null : _col.doc(plan.currentBookingId);
      final current =
          currentRef == null ? null : _fromSnap(await tx.get(currentRef));
      if (current != null &&
          (current.status == BookingStatus.pending ||
              current.status == BookingStatus.accepted)) {
        tx.update(currentRef!, {
          'status': BookingStatus.cancelled.name,
          'cancelledBy': byUid,
          'cancelReason': 'Plan ended',
          if (current.paymentStatus == PaymentStatus.held)
            'paymentStatus': PaymentStatus.refunded.name,
        });
      }
      _stopPlan(tx, plan, byUid);
      return plan;
    });

    final byCustomer = byUid == plan.customerId;
    final other = byCustomer ? plan.providerId : plan.customerId;
    if (other != null) {
      await _notifications.notify(
        userId: other,
        title: '${plan.recurrence.label} plan ended',
        body: byCustomer
            ? '${plan.customerName} ended the plan after '
                '${plan.completedVisits} of ${plan.totalVisits} visits.'
            : '${plan.providerName} ended the plan. You can book a new '
                'cleaner anytime.',
        bookingId: plan.currentBookingId,
      );
    }
  }

  // --------------------------------------------------------------- helpers

  Future<RecurringPlan?> _readPlan(Transaction tx, String? planId) async {
    if (planId == null) return null;
    final snap = await tx.get(_plans.doc(planId));
    return snap.exists ? RecurringPlan.fromMap(snap.id, snap.data()!) : null;
  }

  /// After [visit] is completed or skipped, creates the plan's next visit one
  /// interval after it, or closes the plan after the last one. Must run after
  /// the transaction's reads. Returns the new visit, if any.
  ({String id, DateTime date})? _advancePlan(
    Transaction tx,
    RecurringPlan? plan,
    Booking visit, {
    required bool completed,
  }) {
    if (plan == null || !plan.active) return null;
    final planRef = _plans.doc(plan.id);
    final completedInc = {
      if (completed) 'completedVisits': FieldValue.increment(1),
    };
    if (!plan.hasMoreVisits) {
      tx.update(planRef, {
        ...completedInc,
        'active': false,
        'currentBookingId': null,
      });
      return null;
    }
    final date = nextVisitDate(visit.scheduledDate, plan.recurrence);
    final ref = _col.doc();
    tx.set(ref, visit.nextVisitDoc(date, plan.visitsCreated + 1));
    tx.update(planRef, {
      ...completedInc,
      'visitsCreated': plan.visitsCreated + 1,
      'currentBookingId': ref.id,
    });
    return (id: ref.id, date: date);
  }

  ({String id, DateTime date})? _stopPlan(
      Transaction tx, RecurringPlan? plan, String byUid) {
    if (plan == null || !plan.active) return null;
    tx.update(_plans.doc(plan.id), {
      'active': false,
      'endedBy': byUid,
      'currentBookingId': null,
    });
    return null;
  }

  /// One interval after [from], moved forward past today if the visit before
  /// it was confirmed late.
  static DateTime nextVisitDate(DateTime from, Recurrence r, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    var d = from.add(Duration(days: r.intervalDays));
    while (d.isBefore(today)) {
      d = d.add(Duration(days: r.intervalDays));
    }
    return d;
  }

  Future<void> _notifyNextVisit(
    Booking prev,
    ({String id, DateTime date})? next, {
    bool skipped = false,
  }) async {
    if (next == null || prev.providerId == null) return;
    final when = '${formatDate(next.date)}, ${prev.timeSlot}';
    final payNote = prev.paymentMethod == PaymentMethod.gcash
        ? ' Pay through GCash before the visit.'
        : '';
    await _notifications.notify(
      userId: prev.customerId,
      title: skipped ? 'Visit skipped' : 'Next cleaning scheduled',
      body: 'Your next ${prev.recurrence.label.toLowerCase()} visit with '
          '${prev.providerName} is on $when.$payNote',
      bookingId: next.id,
    );
    await _notifications.notify(
      userId: prev.providerId!,
      title: skipped ? 'Visit skipped' : 'Next visit scheduled',
      body: 'Next visit with ${prev.customerName} is on $when.',
      bookingId: next.id,
    );
  }

  Future<Booking> _transition(
    String bookingId, {
    required String actor,
    required Set<BookingStatus> from,
    required BookingStatus to,
    void Function(Booking b)? guard,
  }) =>
      _db.runTransaction((tx) async {
        final snap = await tx.get(_col.doc(bookingId));
        final b = _fromSnap(snap);
        if (b.providerId != actor) {
          throw BookingException('This job is assigned to someone else.');
        }
        if (!from.contains(b.status)) {
          throw BookingException('This job is already "${b.status.label}".');
        }
        guard?.call(b);
        tx.update(snap.reference, {'status': to.name});
        return b;
      });
}
