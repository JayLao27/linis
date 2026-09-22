import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../data/backend.dart';
import '../data/models/address.dart';
import '../data/models/app_user.dart';
import '../data/models/booking.dart';
import '../data/models/enums.dart';
import '../data/models/provider_profile.dart';
import '../data/services/pricing_service.dart';

/// State of the booking flow. The estimate is recomputed whenever the service,
/// home size, tier filter, address or chosen provider changes.
class BookingDraft extends ChangeNotifier {
  BookingDraft(this._backend, {ServiceType? service, ProviderProfile? provider})
      : serviceType = service ?? provider?.servicesOffered.firstOrNull ??
            ServiceType.regular,
        chosenProvider = provider,
        tierFilter = TierFilter.any;

  final Backend _backend;
  StreamSubscription<List<ProviderProfile>>? _candidatesSub;

  ServiceType serviceType;
  HomeSize homeSize = HomeSize.small;
  DateTime? date;
  String? timeSlot;
  Address? address;
  String notes = '';
  TierFilter tierFilter;
  PaymentMethod paymentMethod = PaymentMethod.gcash;

  /// Provider picked from search results or a profile. Null = send the
  /// request to every matching provider.
  ProviderProfile? chosenProvider;

  List<ProviderProfile> candidates = const [];
  bool loadingCandidates = false;

  PricingService get _pricing => _backend.pricing;

  PriceRange get estimate {
    final p = chosenProvider;
    if (p != null) {
      final q = _pricing.quoteFor(p, serviceType, homeSize);
      return PriceRange(q, q);
    }
    return _pricing.estimate(
      service: serviceType,
      size: homeSize,
      tierFilter: tierFilter,
      candidates: candidates,
    );
  }

  double quoteFor(ProviderProfile p) =>
      _pricing.quoteFor(p, serviceType, homeSize);

  /// Candidates narrowed by the tier filter and service type.
  List<ProviderProfile> get visibleCandidates => candidates
      .where((p) => tierFilter.allows(p.tier) && p.offers(serviceType))
      .toList();

  void setService(ServiceType s) {
    serviceType = s;
    if (s.companyOnly && tierFilter == TierFilter.individual) {
      tierFilter = TierFilter.any;
    }
    _dropChosenIfIneligible();
    notifyListeners();
  }

  void setHomeSize(HomeSize h) {
    homeSize = h;
    notifyListeners();
  }

  void setDate(DateTime d) {
    date = d;
    notifyListeners();
  }

  void setTimeSlot(String s) {
    timeSlot = s;
    notifyListeners();
  }

  void setTierFilter(TierFilter t) {
    tierFilter = t;
    _dropChosenIfIneligible();
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod m) {
    paymentMethod = m;
    notifyListeners();
  }

  void choose(ProviderProfile? p) {
    chosenProvider = p;
    notifyListeners();
  }

  void setAddress(Address? a) {
    final changedBarangay = a?.barangay.code != address?.barangay.code;
    address = a;
    if (changedBarangay) _loadCandidates();
    notifyListeners();
  }

  void _loadCandidates() {
    _candidatesSub?.cancel();
    final code = address?.barangay.code;
    if (code == null) {
      candidates = const [];
      return;
    }
    loadingCandidates = true;
    _candidatesSub =
        _backend.providers.watchMatching(barangayCode: code).listen((list) {
      candidates = list;
      loadingCandidates = false;
      _dropChosenIfIneligible();
      notifyListeners();
    });
  }

  void _dropChosenIfIneligible() {
    final p = chosenProvider;
    if (p == null) return;
    final coversAddress = address == null ||
        loadingCandidates ||
        candidates.any((c) => c.uid == p.uid);
    if (!tierFilter.allows(p.tier) || !p.offers(serviceType) || !coversAddress) {
      chosenProvider = null;
    }
  }

  /// Why the draft can't be submitted yet, or null if it can.
  String? get problem {
    if (date == null) return 'Pick a date.';
    if (timeSlot == null) return 'Pick a time.';
    if (address == null) return 'Add your address.';
    if (serviceType.companyOnly && tierFilter == TierFilter.individual) {
      return '${serviceType.label} is only offered by companies.';
    }
    return null;
  }

  Booking toBooking(AppUser customer) {
    final est = estimate;
    return Booking(
      id: '',
      customerId: customer.uid,
      customerName: customer.fullName,
      customerPhone: customer.phone,
      requestedProviderId: chosenProvider?.uid,
      tierFilter: tierFilter,
      serviceType: serviceType,
      homeSize: homeSize,
      scheduledDate: date!,
      timeSlot: timeSlot ?? kTimeSlots.first,
      address: address!,
      notes: notes.trim(),
      estimateMin: est.min,
      estimateMax: est.max,
      paymentMethod: paymentMethod,
    );
  }

  @override
  void dispose() {
    _candidatesSub?.cancel();
    super.dispose();
  }
}
