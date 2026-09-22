import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../models/enums.dart';
import '../models/provider_profile.dart';
import 'notification_repository.dart';

class ProviderRepository {
  ProviderRepository(this._db, this._notifications);
  final FirebaseFirestore _db;
  final NotificationRepository _notifications;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('providers');

  ProviderProfile? _fromSnap(DocumentSnapshot<Map<String, dynamic>> s) =>
      s.exists ? ProviderProfile.fromMap(s.id, s.data()!) : null;

  Stream<ProviderProfile?> watch(String uid) =>
      _col.doc(uid).snapshots().map(_fromSnap);

  Future<ProviderProfile?> get(String uid) async =>
      _fromSnap(await _col.doc(uid).get());

  /// Called at registration, before onboarding details are filled in.
  Future<void> createDraft({
    required String uid,
    required ProviderTier tier,
    required String displayName,
    required String phone,
    String? businessName,
  }) =>
      _col.doc(uid).set(ProviderProfile(
            uid: uid,
            tier: tier,
            displayName: displayName,
            phone: phone,
            businessName: businessName,
            baseRate: tier.defaultBaseRate,
            servicesOffered: const [ServiceType.regular],
          ).toNewDocMap());

  /// Saves onboarding details. Submitting sends the profile to the admin
  /// queue; the documents are checked by hand before approval.
  Future<void> saveProfile(ProviderProfile p, {bool submit = false}) {
    _validate(p, forSubmit: submit);
    return _col.doc(p.uid).update({
      ...p.toEditableMap(),
      if (submit) 'verificationStatus': VerificationStatus.pending.name,
      if (submit) 'rejectionReason': null,
    });
  }

  void _validate(ProviderProfile p, {required bool forSubmit}) {
    if (p.serviceAreas.length > Business.maxServiceAreas) {
      throw ArgumentError(
          'Pick at most ${Business.maxServiceAreas} service areas.');
    }
    if (!p.isCompany && p.servicesOffered.any((s) => s.companyOnly)) {
      throw ArgumentError('Only companies can offer post-construction cleaning.');
    }
    if (!forSubmit) return;
    final missing = <String>[
      if (p.serviceAreas.isEmpty) 'at least one service area',
      if (p.servicesOffered.isEmpty) 'at least one service',
      if (p.baseRate <= 0) 'your base rate',
      if (p.isCompany && (p.businessName ?? '').isEmpty) 'business name',
      if (p.isCompany && (p.businessRegNo ?? '').isEmpty)
        'business registration number',
      if (p.isCompany && p.permitUrl == null) 'business permit photo',
      if (!p.isCompany && p.govIdUrl == null) 'government ID photo',
    ];
    if (missing.isNotEmpty) {
      throw ArgumentError('Please add ${missing.join(', ')}.');
    }
  }

  /// Approved providers who cover [barangayCode]. Tier, service and pause
  /// checks are applied in memory to keep the query on one composite index.
  Stream<List<ProviderProfile>> watchMatching({
    required String barangayCode,
    ServiceType? service,
    TierFilter tierFilter = TierFilter.any,
  }) =>
      _col
          .where('verificationStatus',
              isEqualTo: VerificationStatus.approved.name)
          .where('serviceAreas', arrayContains: barangayCode)
          .snapshots()
          .map((s) => s.docs
              .map((d) => ProviderProfile.fromMap(d.id, d.data()))
              .where((p) =>
                  tierFilter.allows(p.tier) &&
                  (service == null || p.offers(service)) &&
                  !p.bookingsPaused)
              .toList()
            ..sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg)));

  Future<List<ProviderProfile>> matching({
    required String barangayCode,
    ServiceType? service,
    TierFilter tierFilter = TierFilter.any,
  }) =>
      watchMatching(
              barangayCode: barangayCode,
              service: service,
              tierFilter: tierFilter)
          .first;

  /// All approved providers, for browsing without an address yet.
  Stream<List<ProviderProfile>> watchApproved({TierFilter tier = TierFilter.any}) =>
      _col
          .where('verificationStatus',
              isEqualTo: VerificationStatus.approved.name)
          .snapshots()
          .map((s) => s.docs
              .map((d) => ProviderProfile.fromMap(d.id, d.data()))
              .where((p) => tier.allows(p.tier))
              .toList()
            ..sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg)));

  // ---- Admin ----

  Stream<List<ProviderProfile>> watchByStatus(VerificationStatus status) => _col
      .where('verificationStatus', isEqualTo: status.name)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ProviderProfile.fromMap(d.id, d.data()))
          .toList());

  Stream<List<ProviderProfile>> watchWithUnsettledCommission() => _col
      .where('unsettledCommission', isGreaterThan: 0)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ProviderProfile.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.unsettledCommission.compareTo(a.unsettledCommission)));

  Future<void> approve(String uid) async {
    await _col.doc(uid).update({
      'verificationStatus': VerificationStatus.approved.name,
      'rejectionReason': null,
    });
    await _notifications.notify(
      userId: uid,
      title: 'You are verified',
      body: 'Your documents were approved. Job requests in your service '
          'areas will now reach you.',
    );
  }

  Future<void> reject(String uid, String reason) async {
    await _col.doc(uid).update({
      'verificationStatus': VerificationStatus.rejected.name,
      'rejectionReason': reason,
    });
    await _notifications.notify(
      userId: uid,
      title: 'Verification needs changes',
      body: reason,
    );
  }
}
