import 'package:flutter_test/flutter_test.dart';
import 'package:linis/core/constants.dart';
import 'package:linis/data/backend.dart';
import 'package:linis/data/demo_seed.dart';
import 'package:linis/data/models/booking.dart';
import 'package:linis/data/models/enums.dart';
import 'package:linis/data/models/provider_profile.dart';
import 'package:linis/data/models/review.dart';
import 'package:linis/data/repositories/booking_repository.dart';
import 'package:linis/data/services/pricing_service.dart';

void main() {
  const pricing = PricingService();

  group('PricingService', () {
    test('quote scales base rate by service and size, rounded to ₱10', () {
      expect(
          pricing.quote(
              baseRate: 450, service: ServiceType.deep, size: HomeSize.medium),
          1710);
      expect(
          pricing.quote(
              baseRate: 500,
              service: ServiceType.regular,
              size: HomeSize.studio),
          500);
    });

    test('commission differs by tier', () {
      final ind = pricing.split(1000, ProviderTier.individual);
      final co = pricing.split(1000, ProviderTier.company);
      expect(ind.commission, 100);
      expect(ind.providerShare, 900);
      expect(co.commission, 150);
      expect(co.providerShare, 850);
    });

    test('estimate falls back to tier defaults; company-only jobs skip individuals',
        () {
      final both = pricing.estimate(
          service: ServiceType.regular,
          size: HomeSize.studio,
          tierFilter: TierFilter.any);
      expect(both.min, Business.defaultBaseRateIndividual);
      expect(both.max, Business.defaultBaseRateCompany);

      final post = pricing.estimate(
          service: ServiceType.postConstruction,
          size: HomeSize.studio,
          tierFilter: TierFilter.any);
      expect(post.min, post.max);
    });
  });

  group('Booking lifecycle', () {
    late Backend be;
    late String customerId;
    late String providerId;

    Booking draft({
      PaymentMethod method = PaymentMethod.gcash,
      String? requestedProviderId,
      TierFilter tier = TierFilter.any,
      ServiceType service = ServiceType.regular,
      HomeSize size = HomeSize.small,
      Recurrence recurrence = Recurrence.none,
      int totalVisits = 1,
    }) =>
        Booking(
          id: '',
          customerId: customerId,
          customerName: 'Test Customer',
          requestedProviderId: requestedProviderId,
          tierFilter: tier,
          serviceType: service,
          homeSize: size,
          scheduledDate: DateTime.now().add(const Duration(days: 2)),
          timeSlot: kTimeSlots.first,
          address: DemoSeed.addressIn(DemoSeed.buhangin, '123 Test St.'),
          estimateMin: 0,
          estimateMax: 0,
          paymentMethod: method,
          recurrence: recurrence,
          totalVisits: totalVisits,
        );

    Future<ProviderProfile> provider() async =>
        (await be.providers.get(providerId))!;

    setUp(() async {
      be = await Backend.demo(seed: false);
      customerId = await be.register(
          email: 'c@test.ph',
          password: 'secret1',
          fullName: 'Test Customer',
          phone: '09170000000',
          role: UserRole.customer);
      providerId = await be.register(
          email: 'p@test.ph',
          password: 'secret1',
          fullName: 'Test Cleaner',
          phone: '09170000001',
          role: UserRole.provider,
          tier: ProviderTier.individual);
      final draftProfile = (await provider()).copyWith(
        serviceAreas: [DemoSeed.buhangin.code],
        serviceAreaNames: [DemoSeed.buhangin.name],
        servicesOffered: [ServiceType.regular, ServiceType.deep],
        baseRate: 500,
        govIdType: 'UMID',
        govIdUrl: 'memory://id',
      );
      await be.providers.saveProfile(draftProfile, submit: true);
      expect((await provider()).verificationStatus, VerificationStatus.pending);
      await be.providers.approve(providerId);
    });

    test('submitting without documents is rejected', () async {
      final p = (await provider()).copyWith();
      final noId = ProviderProfile.fromMap(p.uid, {
        ...p.toNewDocMap(),
        'govIdUrl': null,
      });
      expect(() => be.providers.saveProfile(noId, submit: true),
          throwsArgumentError);
    });

    test('GCash job: broadcast → accept → pay → start → finish → confirm',
        () async {
      final id = await be.bookings.create(draft());

      final open = await be.bookings.watchOpenRequests(await provider()).first;
      expect(open.map((b) => b.id), contains(id));

      final notes = await be.notifications.watch(providerId).first;
      expect(notes.any((n) => n.bookingId == id), isTrue);

      await be.bookings.accept(id, providerId);
      var b = (await be.bookings.watch(id).first)!;
      expect(b.status, BookingStatus.accepted);
      expect(b.price, 700); // 500 × 1.0 × 1.4
      expect(b.commissionAmount, 70);

      // Can't start before the customer pays in-app.
      expect(() => be.bookings.start(id, providerId),
          throwsA(isA<BookingException>()));

      await be.bookings.recordGcashPayment(id, 'REF123');
      await be.bookings.start(id, providerId);
      await be.bookings.finish(id, providerId);
      await be.bookings.confirmCompletion(id, customerId);

      b = (await be.bookings.watch(id).first)!;
      expect(b.status, BookingStatus.completed);
      expect(b.paymentStatus, PaymentStatus.released);

      final p = await provider();
      expect(p.completedJobs, 1);
      expect(p.totalEarnings, 630);
      expect(p.unsettledCommission, 0);

      final ledger = await be.ledger.watchForProvider(providerId).first;
      expect(ledger.single.type, LedgerType.gcashRelease);
      expect(ledger.single.amount, 630);
    });

    test('only one provider can accept a request', () async {
      final second = await be.register(
          email: 'p2@test.ph',
          password: 'secret1',
          fullName: 'Second',
          phone: '0917',
          role: UserRole.provider,
          tier: ProviderTier.individual);
      await be.providers.saveProfile(
          (await be.providers.get(second))!.copyWith(
            serviceAreas: [DemoSeed.buhangin.code],
            servicesOffered: [ServiceType.regular],
            baseRate: 400,
            govIdUrl: 'memory://id',
          ),
          submit: true);
      await be.providers.approve(second);

      final id = await be.bookings.create(draft());
      await be.bookings.accept(id, providerId);
      expect(() => be.bookings.accept(id, second),
          throwsA(isA<BookingException>()));
    });

    test('cash commission accumulates and pauses bookings at the cap', () async {
      // Each deep clean of a large home at ₱500 base = ₱2,600 → ₱260 commission.
      for (var i = 0; i < 6; i++) {
        final id = await be.bookings.create(draft(
            method: PaymentMethod.cash,
            service: ServiceType.deep,
            size: HomeSize.large));
        await be.bookings.accept(id, providerId);
        await be.bookings.start(id, providerId);
        await be.bookings.finish(id, providerId);
        await be.bookings.confirmCompletion(id, customerId);
      }
      var p = await provider();
      expect(p.unsettledCommission, 1560);
      expect(p.bookingsPaused, isTrue);

      final blocked = await be.bookings.create(draft(method: PaymentMethod.cash));
      expect(() => be.bookings.accept(blocked, providerId),
          throwsA(isA<BookingException>()));
      final matches =
          await be.providers.matching(barangayCode: DemoSeed.buhangin.code);
      expect(matches.any((m) => m.uid == providerId), isFalse);

      final settled = await be.ledger.settle(providerId, reference: 'SETTLE1');
      expect(settled, 1560);
      p = await provider();
      expect(p.bookingsPaused, isFalse);
      await be.bookings.accept(blocked, providerId);
    });

    test('two-way ratings update averages once per side', () async {
      final id = await be.bookings.create(draft(method: PaymentMethod.cash));
      await be.bookings.accept(id, providerId);
      await be.bookings.start(id, providerId);
      await be.bookings.finish(id, providerId);

      expect(
          () => be.reviews.submit(
              bookingId: id,
              direction: ReviewDirection.customerToProvider,
              fromUid: customerId,
              fromName: 'Test Customer',
              rating: 5),
          throwsA(isA<BookingException>()),
          reason: 'not completed yet');

      await be.bookings.confirmCompletion(id, customerId);
      await be.reviews.submit(
          bookingId: id,
          direction: ReviewDirection.customerToProvider,
          fromUid: customerId,
          fromName: 'Test Customer',
          rating: 4,
          comment: 'Good');
      await be.reviews.submit(
          bookingId: id,
          direction: ReviewDirection.providerToCustomer,
          fromUid: providerId,
          fromName: 'Test Cleaner',
          rating: 5);

      expect((await provider()).ratingAvg, 4);
      expect((await be.users.get(customerId))!.ratingAvg, 5);
      expect(
          () => be.reviews.submit(
              bookingId: id,
              direction: ReviewDirection.customerToProvider,
              fromUid: customerId,
              fromName: 'Test Customer',
              rating: 1),
          throwsA(isA<BookingException>()));
    });

    test('declining a direct request opens it to other providers', () async {
      final id = await be.bookings.create(draft(requestedProviderId: providerId));
      await be.bookings.decline(id, providerId);
      final b = (await be.bookings.watch(id).first)!;
      expect(b.requestedProviderId, isNull);
      expect(b.declinedBy, [providerId]);
      final open = await be.bookings.watchOpenRequests(await provider()).first;
      expect(open.any((o) => o.id == id), isFalse);
    });

    test('tier filter hides requests from the other tier', () async {
      await be.bookings.create(draft(tier: TierFilter.company));
      final open = await be.bookings.watchOpenRequests(await provider()).first;
      expect(open, isEmpty);
    });

    test('cancelling a paid booking refunds it', () async {
      final id = await be.bookings.create(draft());
      await be.bookings.accept(id, providerId);
      await be.bookings.recordGcashPayment(id, 'REF');
      await be.bookings.cancel(id, customerId, reason: 'Plans changed');
      final b = (await be.bookings.watch(id).first)!;
      expect(b.status, BookingStatus.cancelled);
      expect(b.paymentStatus, PaymentStatus.refunded);
    });

    group('recurring plans', () {
      Future<void> runVisit(String id, {bool accept = false}) async {
        if (accept) await be.bookings.accept(id, providerId);
        await be.bookings.start(id, providerId);
        await be.bookings.finish(id, providerId);
        await be.bookings.confirmCompletion(id, customerId);
      }

      test('weekly plan: discounted price, next visit follows completion',
          () async {
        final first = draft(
            method: PaymentMethod.cash,
            recurrence: Recurrence.weekly,
            totalVisits: 4);
        final id = await be.bookings.create(first);
        var b = (await be.bookings.watch(id).first)!;
        expect(b.planId, isNotNull);
        expect(b.visitNumber, 1);

        await be.bookings.accept(id, providerId);
        b = (await be.bookings.watch(id).first)!;
        expect(b.price, 630); // 700 less 10%, rounded to ₱10

        var plan = (await be.bookings.watchPlan(b.planId!).first)!;
        expect(plan.providerId, providerId);
        expect(plan.pricePerVisit, 630);

        await runVisit(id);
        plan = (await be.bookings.watchPlan(b.planId!).first)!;
        expect(plan.completedVisits, 1);
        expect(plan.visitsCreated, 2);

        final next = (await be.bookings.watch(plan.currentBookingId!).first)!;
        expect(next.status, BookingStatus.accepted);
        expect(next.providerId, providerId);
        expect(next.price, 630);
        expect(next.visitNumber, 2);
        expect(next.scheduledDate.difference(first.scheduledDate).inDays, 7);

        final notes = await be.notifications.watch(customerId).first;
        expect(notes.any((n) => n.title == 'Next cleaning scheduled'), isTrue);
      });

      test('skipping a visit schedules the one after it', () async {
        final id = await be.bookings.create(draft(
            method: PaymentMethod.cash,
            recurrence: Recurrence.biweekly,
            totalVisits: 4));
        await be.bookings.accept(id, providerId);
        final b = (await be.bookings.watch(id).first)!;

        await be.bookings.cancel(id, customerId, reason: 'Away');
        final plan = (await be.bookings.watchPlan(b.planId!).first)!;
        expect(plan.active, isTrue);
        expect(plan.completedVisits, 0);
        final next = (await be.bookings.watch(plan.currentBookingId!).first)!;
        expect(next.visitNumber, 2);
        expect(next.scheduledDate.difference(b.scheduledDate).inDays, 14);
      });

      test('plan closes after its last visit', () async {
        final id = await be.bookings.create(draft(
            method: PaymentMethod.cash,
            recurrence: Recurrence.weekly,
            totalVisits: 4));
        await runVisit(id, accept: true);
        final planId = (await be.bookings.watch(id).first)!.planId!;
        for (var i = 0; i < 3; i++) {
          final plan = (await be.bookings.watchPlan(planId).first)!;
          await runVisit(plan.currentBookingId!);
        }
        final plan = (await be.bookings.watchPlan(planId).first)!;
        expect(plan.active, isFalse);
        expect(plan.completedVisits, 4);
        expect(plan.currentBookingId, isNull);
        expect(plan.endedBy, isNull);
        expect((await provider()).completedJobs, 4);
      });

      test('ending a plan cancels and refunds the open visit', () async {
        final id = await be.bookings.create(
            draft(recurrence: Recurrence.weekly, totalVisits: 8));
        await be.bookings.accept(id, providerId);
        await be.bookings.recordGcashPayment(id, 'REF');
        final planId = (await be.bookings.watch(id).first)!.planId!;

        await be.bookings.endPlan(planId, customerId);
        final b = (await be.bookings.watch(id).first)!;
        expect(b.status, BookingStatus.cancelled);
        expect(b.paymentStatus, PaymentStatus.refunded);
        final plan = (await be.bookings.watchPlan(planId).first)!;
        expect(plan.active, isFalse);
        expect(plan.endedBy, customerId);
        expect(() => be.bookings.endPlan(planId, customerId),
            throwsA(isA<BookingException>()));
      });

      test('cancelling before anyone accepts ends the plan', () async {
        final id = await be.bookings.create(
            draft(recurrence: Recurrence.weekly, totalVisits: 4));
        await be.bookings.cancel(id, customerId);
        final planId = (await be.bookings.watch(id).first)!.planId!;
        final plan = (await be.bookings.watchPlan(planId).first)!;
        expect(plan.active, isFalse);
        expect(plan.visitsCreated, 1);
      });

      test('late confirmation moves the next visit past today', () {
        final now = DateTime(2026, 9, 22);
        final next = BookingRepository.nextVisitDate(
            DateTime(2026, 9, 1), Recurrence.weekly, now);
        expect(next, DateTime(2026, 9, 22));
      });
    });
  });

  test('demo seed signs in and matches Buhangin providers', () async {
    final be = await Backend.demo();
    await be.auth.signIn(DemoSeed.customerEmail, DemoSeed.password);
    final matches =
        await be.providers.matching(barangayCode: DemoSeed.buhangin.code);
    final names = matches.map((p) => p.displayName).toList();
    expect(names, containsAll(['SparkleCrew Cleaning Services', 'Maria Santos']));
    // Ana is over the commission cap, so she is hidden.
    expect(names, isNot(contains('Ana Reyes')));
  });
}
