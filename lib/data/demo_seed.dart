import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/address.dart';
import 'models/enums.dart';
import 'models/review.dart';
import 'repositories/auth_repository.dart';
import 'services/pricing_service.dart';

/// Sample data for the demo backend: the launch barangays from the proposal
/// (Buhangin, Matina Crossing, Talomo) plus a few neighbours, a handful of
/// companies and individual cleaners, and one account per role.
///
/// Every demo account uses the password [password].
class DemoSeed {
  DemoSeed(this._db, this._auth);
  final FirebaseFirestore _db;
  final DemoAuthRepository _auth;

  static const password = 'linis123';

  static const customerEmail = 'customer@linis.ph';
  static const individualEmail = 'maria@linis.ph';
  static const companyEmail = 'sparkle@linis.ph';
  static const pendingEmail = 'rosa@linis.ph';
  static const adminEmail = 'admin@linis.ph';

  static const buhangin = PsgcPlace(code: '112402021', name: 'Buhangin (Pob.)');
  static const matinaCrossing =
      PsgcPlace(code: '112402075', name: 'Matina Crossing');
  static const matinaAplaya = PsgcPlace(code: '112402074', name: 'Matina Aplaya');
  static const talomo = PsgcPlace(code: '112402116', name: 'Talomo (Pob.)');
  static const mintal = PsgcPlace(code: '112402079', name: 'Mintal');

  static const _region = PsgcPlace(code: '110000000', name: 'Davao Region');
  static const _province = PsgcPlace(code: '112400000', name: 'Davao del Sur');
  static const _city = PsgcPlace(code: '112402000', name: 'City of Davao');

  static Address addressIn(PsgcPlace barangay, String street) => Address(
        region: _region,
        province: _province,
        city: _city,
        barangay: barangay,
        street: street,
      );

  final _now = DateTime.now();
  DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));
  DateTime _daysAhead(int d) =>
      DateTime(_now.year, _now.month, _now.day).add(Duration(days: d));

  Future<void> run() async {
    await _users();
    await _providers();
    await _bookingsAndReviews();
  }

  Future<void> _account(String uid, String email, UserRole role, String name,
      String phone, {double ratingAvg = 0, int ratingCount = 0}) async {
    _auth.addAccount(email, password, uid);
    await _db.collection('users').doc(uid).set({
      'role': role.name,
      'fullName': name,
      'email': email,
      'phone': phone,
      'photoUrl': null,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'createdAt': Timestamp.fromDate(_daysAgo(60)),
    });
  }

  Future<void> _users() async {
    await _account('cust-carla', customerEmail, UserRole.customer,
        'Carla Mendoza', '09171234567', ratingAvg: 5, ratingCount: 1);
    await _account('cust-ben', 'ben@linis.ph', UserRole.customer,
        'Ben Tan', '09181112222', ratingAvg: 4.5, ratingCount: 2);
    await _account('admin', adminEmail, UserRole.admin, 'Linis Admin',
        '09000000000');
    await _account('prov-sparkle', companyEmail, UserRole.provider,
        'Liza Gomez', '09221234567');
    await _account('prov-kalimpyo', 'kalimpyo@linis.ph', UserRole.provider,
        'Ramon Uy', '09231234567');
    await _account('prov-maria', individualEmail, UserRole.provider,
        'Maria Santos', '09351234567');
    await _account('prov-jun', 'jun@linis.ph', UserRole.provider,
        'Jun Dela Cruz', '09361234567');
    await _account('prov-ana', 'ana@linis.ph', UserRole.provider, 'Ana Reyes',
        '09371234567');
    await _account('prov-rosa', pendingEmail, UserRole.provider,
        'Rosa Villanueva', '09381234567');
    await _account('prov-cleanpro', 'cleanpro@linis.ph', UserRole.provider,
        'Dennis Lim', '09391234567');
  }

  Future<void> _provider(String uid, Map<String, dynamic> data) =>
      _db.collection('providers').doc(uid).set({
        'photoUrl': null,
        'rejectionReason': null,
        'ratingAvg': 0,
        'ratingCount': 0,
        'completedJobs': 0,
        'unsettledCommission': 0,
        'totalEarnings': 0,
        'businessName': null,
        'businessRegNo': null,
        'permitUrl': null,
        'crewSize': 0,
        'equipment': <String>[],
        'govIdType': null,
        'govIdUrl': null,
        'yearsExperience': 0,
        'createdAt': Timestamp.fromDate(_daysAgo(45)),
        ...data,
      });

  Map<String, dynamic> _areas(List<PsgcPlace> places) => {
        'serviceAreas': places.map((p) => p.code).toList(),
        'serviceAreaNames': places.map((p) => p.name).toList(),
      };

  List<String> _services(List<ServiceType> s) => s.map((e) => e.name).toList();

  Future<void> _providers() async {
    await _provider('prov-sparkle', {
      'tier': ProviderTier.company.name,
      'displayName': 'SparkleCrew Cleaning Services',
      'bio': 'Davao-based cleaning company since 2016. Uniformed, trained '
          'crews with commercial equipment for homes of any size.',
      'phone': '09221234567',
      'verificationStatus': VerificationStatus.approved.name,
      ..._areas([buhangin, matinaCrossing, talomo]),
      'servicesOffered': _services(ServiceType.values),
      'baseRate': 900,
      'businessName': 'SparkleCrew Cleaning Services',
      'businessRegNo': 'DTI-11-2016-004821',
      'permitUrl': 'seed://permit',
      'crewSize': 12,
      'equipment': [
        'Industrial vacuum',
        'Floor scrubber',
        'Pressure washer',
        'Steam cleaner'
      ],
      'ratingAvg': 4.8,
      'ratingCount': 32,
      'completedJobs': 41,
      'totalEarnings': 86400,
    });
    await _provider('prov-kalimpyo', {
      'tier': ProviderTier.company.name,
      'displayName': 'Kalimpyo Davao Inc.',
      'bio': 'Deep cleaning and post-construction specialists serving the '
          'Matina and Talomo area.',
      'phone': '09231234567',
      'verificationStatus': VerificationStatus.approved.name,
      ..._areas([matinaCrossing, matinaAplaya, talomo]),
      'servicesOffered': _services(ServiceType.values),
      'baseRate': 800,
      'businessName': 'Kalimpyo Davao Inc.',
      'businessRegNo': 'SEC-CS201912345',
      'permitUrl': 'seed://permit',
      'crewSize': 6,
      'equipment': ['Wet/dry vacuum', 'Floor polisher', 'Ladders'],
      'ratingAvg': 4.5,
      'ratingCount': 18,
      'completedJobs': 22,
      'totalEarnings': 38100,
    });
    await _provider('prov-maria', {
      'tier': ProviderTier.individual.name,
      'displayName': 'Maria Santos',
      'bio': 'Six years cleaning homes and condos around Buhangin. Detail-'
          'oriented, brings my own basic supplies.',
      'phone': '09351234567',
      'verificationStatus': VerificationStatus.approved.name,
      ..._areas([buhangin, matinaCrossing]),
      'servicesOffered':
          _services([ServiceType.regular, ServiceType.deep, ServiceType.moveInOut]),
      'baseRate': 450,
      'govIdType': 'PhilSys National ID',
      'govIdUrl': 'seed://id',
      'yearsExperience': 6,
      'ratingAvg': 4.9,
      'ratingCount': 27,
      'completedJobs': 30,
      'unsettledCommission': 180,
      'totalEarnings': 19800,
    });
    await _provider('prov-jun', {
      'tier': ProviderTier.individual.name,
      'displayName': 'Jun Dela Cruz',
      'bio': 'Reliable weekly cleaning for apartments and small houses.',
      'phone': '09361234567',
      'verificationStatus': VerificationStatus.approved.name,
      ..._areas([matinaCrossing, talomo]),
      'servicesOffered': _services([ServiceType.regular, ServiceType.deep]),
      'baseRate': 400,
      'govIdType': "Driver's License",
      'govIdUrl': 'seed://id',
      'yearsExperience': 3,
      'ratingAvg': 4.6,
      'ratingCount': 12,
      'completedJobs': 14,
      'totalEarnings': 7200,
    });
    await _provider('prov-ana', {
      'tier': ProviderTier.individual.name,
      'displayName': 'Ana Reyes',
      'bio': 'Former hotel housekeeper. Thorough deep cleans and move-outs.',
      'phone': '09371234567',
      'verificationStatus': VerificationStatus.approved.name,
      ..._areas([talomo, mintal, buhangin]),
      'servicesOffered':
          _services([ServiceType.regular, ServiceType.deep, ServiceType.moveInOut]),
      'baseRate': 500,
      'govIdType': 'Passport',
      'govIdUrl': 'seed://id',
      'yearsExperience': 8,
      'ratingAvg': 4.7,
      'ratingCount': 9,
      'completedJobs': 11,
      // Over the cap: shows how unsettled cash commission pauses bookings.
      'unsettledCommission': 1520,
      'totalEarnings': 9100,
    });
    await _provider('prov-rosa', {
      'tier': ProviderTier.individual.name,
      'displayName': 'Rosa Villanueva',
      'bio': 'Part-time cleaner, weekends and afternoons.',
      'phone': '09381234567',
      'verificationStatus': VerificationStatus.pending.name,
      ..._areas([buhangin]),
      'servicesOffered': _services([ServiceType.regular]),
      'baseRate': 420,
      'govIdType': 'UMID',
      'govIdUrl': 'seed://id',
      'yearsExperience': 2,
      'createdAt': Timestamp.fromDate(_daysAgo(1)),
    });
    await _provider('prov-cleanpro', {
      'tier': ProviderTier.company.name,
      'displayName': 'CleanPro Mindanao',
      'bio': 'Commercial and residential cleaning.',
      'phone': '09391234567',
      'verificationStatus': VerificationStatus.pending.name,
      ..._areas([buhangin, talomo]),
      'servicesOffered': _services(ServiceType.values),
      'baseRate': 1000,
      'businessName': 'CleanPro Mindanao Services',
      'businessRegNo': 'DTI-11-2024-118930',
      'permitUrl': 'seed://permit',
      'crewSize': 9,
      'equipment': ['Industrial vacuum', 'Scaffolding'],
      'createdAt': Timestamp.fromDate(_daysAgo(2)),
    });
  }

  Future<void> _bookingsAndReviews() async {
    const pricing = PricingService();
    final bookings = _db.collection('bookings');
    final carlaHome = addressIn(buhangin, 'Unit 4B, Palm Residences, Km. 7');
    final benHome = addressIn(matinaCrossing, 'Blk 3 Lot 12, Ecoland Subd.');

    Map<String, dynamic> base({
      required String customerId,
      required String customerName,
      required String phone,
      required Address address,
      required ServiceType service,
      required HomeSize size,
      required DateTime date,
      required String slot,
      required PaymentMethod method,
      TierFilter tier = TierFilter.any,
    }) {
      final est = pricing.estimate(
          service: service, size: size, tierFilter: tier);
      return {
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': phone,
        'providerId': null,
        'providerName': null,
        'providerTier': null,
        'requestedProviderId': null,
        'tierFilter': tier.name,
        'serviceType': service.name,
        'homeSize': size.name,
        'scheduledDate': Timestamp.fromDate(date),
        'timeSlot': slot,
        'address': address.toMap(),
        'barangayCode': address.barangay.code,
        'notes': '',
        'estimateMin': est.min,
        'estimateMax': est.max,
        'price': null,
        'paymentMethod': method.name,
        'paymentStatus': PaymentStatus.unpaid.name,
        'status': BookingStatus.pending.name,
        'declinedBy': <String>[],
        'customerRated': false,
        'providerRated': false,
      };
    }

    Map<String, dynamic> assigned(String providerId, String providerName,
        ProviderTier tier, double baseRate, ServiceType s, HomeSize h,
        [Recurrence recurrence = Recurrence.none]) {
      final price = pricing.withDiscount(
          pricing.quote(baseRate: baseRate, service: s, size: h), recurrence);
      final split = pricing.split(price, tier);
      return {
        'providerId': providerId,
        'providerName': providerName,
        'providerTier': tier.name,
        'price': price,
        'commissionRate': split.rate,
        'commissionAmount': split.commission,
        'providerShare': split.providerShare,
      };
    }

    // Carla: a finished, two-way-rated deep clean with SparkleCrew.
    await bookings.doc('seed-b1').set({
      ...base(
          customerId: 'cust-carla',
          customerName: 'Carla Mendoza',
          phone: '09171234567',
          address: carlaHome,
          service: ServiceType.deep,
          size: HomeSize.small,
          date: _daysAgo(9),
          slot: '8:00 AM',
          method: PaymentMethod.gcash),
      ...assigned('prov-sparkle', 'SparkleCrew Cleaning Services',
          ProviderTier.company, 900, ServiceType.deep, HomeSize.small),
      'status': BookingStatus.completed.name,
      'paymentStatus': PaymentStatus.released.name,
      'paymentRef': '4012998812034',
      'customerRated': true,
      'providerRated': true,
      'createdAt': Timestamp.fromDate(_daysAgo(12)),
      'acceptedAt': Timestamp.fromDate(_daysAgo(12)),
      'completedAt': Timestamp.fromDate(_daysAgo(9)),
    });

    // Carla: an open broadcast request that Buhangin providers can accept.
    await bookings.doc('seed-b2').set({
      ...base(
          customerId: 'cust-carla',
          customerName: 'Carla Mendoza',
          phone: '09171234567',
          address: carlaHome,
          service: ServiceType.regular,
          size: HomeSize.small,
          date: _daysAhead(3),
          slot: '10:00 AM',
          method: PaymentMethod.cash),
      'notes': 'Please bring a mop, we only have a broom.',
      'createdAt': Timestamp.fromDate(_now.subtract(const Duration(hours: 2))),
    });

    // Ben: visit 1 of a weekly plan with Maria, accepted, tomorrow.
    await bookings.doc('seed-b3').set({
      ...base(
          customerId: 'cust-ben',
          customerName: 'Ben Tan',
          phone: '09181112222',
          address: benHome,
          service: ServiceType.regular,
          size: HomeSize.medium,
          date: _daysAhead(1),
          slot: '1:00 PM',
          method: PaymentMethod.cash),
      ...assigned('prov-maria', 'Maria Santos', ProviderTier.individual, 450,
          ServiceType.regular, HomeSize.medium, Recurrence.weekly),
      'status': BookingStatus.accepted.name,
      'requestedProviderId': 'prov-maria',
      'planId': 'seed-plan1',
      'recurrence': Recurrence.weekly.name,
      'visitNumber': 1,
      'totalVisits': 8,
      'createdAt': Timestamp.fromDate(_daysAgo(1)),
      'acceptedAt': Timestamp.fromDate(_daysAgo(1)),
    });
    // Ben and Maria have been messaging; Ben's last message is unread.
    final chat = bookings.doc('seed-b3').collection('messages');
    final msgs = [
      ('prov-maria', 'Maria Santos',
          'Hi Sir Ben! Maria here, confirming tomorrow at 1 PM.', 20),
      ('cust-ben', 'Ben Tan',
          'Hi Maria! Yes please. The guard will let you in, just mention Blk 3 Lot 12.',
          18),
      ('cust-ben', 'Ben Tan',
          'Also, we have a cat. She is friendly but please keep the screen door closed.',
          17),
    ];
    for (final (from, name, text, hoursAgo) in msgs) {
      await chat.add({
        'senderId': from,
        'senderName': name,
        'text': text,
        'createdAt':
            Timestamp.fromDate(_now.subtract(Duration(hours: hoursAgo))),
      });
    }
    await bookings.doc('seed-b3').update({
      'lastMessageText': msgs.last.$3,
      'lastMessageBy': 'cust-ben',
      'lastMessageAt':
          Timestamp.fromDate(_now.subtract(const Duration(hours: 17))),
      'customerReadAt':
          Timestamp.fromDate(_now.subtract(const Duration(hours: 17))),
      'providerReadAt':
          Timestamp.fromDate(_now.subtract(const Duration(hours: 20))),
    });

    await _db.collection('plans').doc('seed-plan1').set({
      'customerId': 'cust-ben',
      'customerName': 'Ben Tan',
      'providerId': 'prov-maria',
      'providerName': 'Maria Santos',
      'recurrence': Recurrence.weekly.name,
      'totalVisits': 8,
      'visitsCreated': 1,
      'completedVisits': 0,
      'active': true,
      'currentBookingId': 'seed-b3',
      'pricePerVisit': pricing.withDiscount(
          pricing.quote(
              baseRate: 450,
              service: ServiceType.regular,
              size: HomeSize.medium),
          Recurrence.weekly),
      'endedBy': null,
      'createdAt': Timestamp.fromDate(_daysAgo(1)),
    });

    // Ben: an earlier cash job with Maria, completed and rated.
    await bookings.doc('seed-b4').set({
      ...base(
          customerId: 'cust-ben',
          customerName: 'Ben Tan',
          phone: '09181112222',
          address: benHome,
          service: ServiceType.deep,
          size: HomeSize.medium,
          date: _daysAgo(5),
          slot: '8:00 AM',
          method: PaymentMethod.cash),
      ...assigned('prov-maria', 'Maria Santos', ProviderTier.individual, 450,
          ServiceType.deep, HomeSize.medium),
      'status': BookingStatus.completed.name,
      'paymentStatus': PaymentStatus.cashCollected.name,
      'customerRated': true,
      'providerRated': true,
      'createdAt': Timestamp.fromDate(_daysAgo(7)),
      'acceptedAt': Timestamp.fromDate(_daysAgo(7)),
      'completedAt': Timestamp.fromDate(_daysAgo(5)),
    });

    final reviews = _db.collection('reviews');
    Future<void> review(String id, String bookingId, ReviewDirection dir,
            String from, String fromName, String to, int rating,
            String comment, int daysAgo) =>
        reviews.doc(id).set({
          'bookingId': bookingId,
          'direction': dir.name,
          'fromUid': from,
          'fromName': fromName,
          'toUid': to,
          'rating': rating,
          'comment': comment,
          'createdAt': Timestamp.fromDate(_daysAgo(daysAgo)),
        });

    const c2p = ReviewDirection.customerToProvider;
    const p2c = ReviewDirection.providerToCustomer;
    await review('seed-b1_${c2p.name}', 'seed-b1', c2p, 'cust-carla',
        'Carla Mendoza', 'prov-sparkle', 5,
        'Crew of three arrived on time and the kitchen looks brand new.', 9);
    await review('seed-b1_${p2c.name}', 'seed-b1', p2c, 'prov-sparkle',
        'SparkleCrew Cleaning Services', 'cust-carla', 5,
        'Clear instructions and easy parking. Thank you!', 9);
    await review('seed-b4_${c2p.name}', 'seed-b4', c2p, 'cust-ben', 'Ben Tan',
        'prov-maria', 5, 'Maria is very careful with our things. Highly '
        'recommended.', 5);
    await review('seed-b4_${p2c.name}', 'seed-b4', p2c, 'prov-maria',
        'Maria Santos', 'cust-ben', 4, 'Friendly household, paid on time.', 5);
    await review('seed-r1', 'seed-old1', c2p, 'cust-ben', 'Ben Tan',
        'prov-sparkle', 4, 'Good job overall, a bit late.', 20);
    await review('seed-r2', 'seed-old2', c2p, 'cust-carla', 'Carla Mendoza',
        'prov-jun', 5, 'Quick and tidy. Booked him again.', 14);
    await review('seed-r3', 'seed-old3', c2p, 'cust-ben', 'Ben Tan',
        'prov-kalimpyo', 4, 'Handled the post-renovation dust well.', 30);
    await review('seed-r4', 'seed-old4', c2p, 'cust-carla', 'Carla Mendoza',
        'prov-ana', 5, 'Hotel-level clean.', 18);

    final ledger = _db.collection('ledger');
    await ledger.add({
      'providerId': 'prov-sparkle',
      'type': LedgerType.gcashRelease.name,
      'amount': 2142,
      'commission': 378,
      'bookingId': 'seed-b1',
      'reference': '4012998812034',
      'createdAt': Timestamp.fromDate(_daysAgo(9)),
    });
    await ledger.add({
      'providerId': 'prov-maria',
      'type': LedgerType.cashCommissionDue.name,
      'amount': 1539,
      'commission': 171,
      'bookingId': 'seed-b4',
      'reference': null,
      'createdAt': Timestamp.fromDate(_daysAgo(5)),
    });
    await ledger.add({
      'providerId': 'prov-maria',
      'type': LedgerType.settlement.name,
      'amount': 640,
      'commission': 0,
      'bookingId': null,
      'reference': '4001223344556',
      'createdAt': Timestamp.fromDate(_daysAgo(8)),
    });

    final notifications = _db.collection('notifications');
    await notifications.add({
      'userId': 'prov-maria',
      'title': 'New regular cleaning request',
      'body': '1–2 bedrooms in Buhangin (Pob.). Open it in Requests.',
      'bookingId': 'seed-b2',
      'read': false,
      'createdAt': Timestamp.fromDate(_now.subtract(const Duration(hours: 2))),
    });
    await notifications.add({
      'userId': 'cust-carla',
      'title': 'SparkleCrew rated you 5★',
      'body': 'Clear instructions and easy parking. Thank you!',
      'bookingId': 'seed-b1',
      'read': true,
      'createdAt': Timestamp.fromDate(_daysAgo(9)),
    });
  }
}
