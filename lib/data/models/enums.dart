import '../../core/constants.dart';

enum UserRole { customer, provider, admin }

enum ProviderTier {
  company('Company'),
  individual('Individual');

  const ProviderTier(this.label);
  final String label;

  double get commissionRate => this == ProviderTier.company
      ? Business.commissionCompany
      : Business.commissionIndividual;

  double get defaultBaseRate => this == ProviderTier.company
      ? Business.defaultBaseRateCompany
      : Business.defaultBaseRateIndividual;
}

/// Which tiers a customer wants to see / send a request to.
enum TierFilter {
  any('Both'),
  company('Companies only'),
  individual('Individuals only');

  const TierFilter(this.label);
  final String label;

  bool allows(ProviderTier tier) => switch (this) {
        TierFilter.any => true,
        TierFilter.company => tier == ProviderTier.company,
        TierFilter.individual => tier == ProviderTier.individual,
      };
}

enum VerificationStatus { incomplete, pending, approved, rejected }

enum ServiceType {
  regular('Regular cleaning', 'Weekly or routine tidy-up', 1.0, false),
  deep('Deep cleaning', 'Scrubbing, corners, appliances', 2.0, false),
  moveInOut('Move-in / move-out', 'Empty-home top-to-bottom clean', 2.4, false),
  postConstruction(
      'Post-construction', 'Dust, debris and paint cleanup', 3.5, true);

  const ServiceType(
      this.label, this.description, this.multiplier, this.companyOnly);
  final String label;
  final String description;

  /// Price multiplier applied to a provider's base rate.
  final double multiplier;

  /// Needs crews and heavy equipment, so only companies may offer it.
  final bool companyOnly;
}

enum HomeSize {
  studio('Studio / 1 room', 1.0),
  small('1–2 bedrooms', 1.4),
  medium('3 bedrooms', 1.9),
  large('4+ bedrooms / large house', 2.6);

  const HomeSize(this.label, this.multiplier);
  final String label;
  final double multiplier;
}

enum PaymentMethod {
  gcash('GCash (in-app)'),
  cash('Cash to provider');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentStatus {
  unpaid('Unpaid'),
  held('Paid – held by Linis'),
  released('Paid – released to provider'),
  cashCollected('Paid in cash'),
  refunded('Refunded');

  const PaymentStatus(this.label);
  final String label;
}

enum BookingStatus {
  pending('Finding a cleaner'),
  accepted('Accepted'),
  inProgress('Cleaning in progress'),
  awaitingConfirmation('Awaiting your confirmation'),
  completed('Completed'),
  cancelled('Cancelled');

  const BookingStatus(this.label);
  final String label;

  bool get isActive =>
      this != BookingStatus.completed && this != BookingStatus.cancelled;
}

/// How often a booking repeats. Recurring visits go to the same provider at a
/// discounted per-visit price.
enum Recurrence {
  none('One-time', 0, 0),
  weekly('Every week', 7, Business.weeklyDiscount),
  biweekly('Every 2 weeks', 14, Business.biweeklyDiscount);

  const Recurrence(this.label, this.intervalDays, this.discount);
  final String label;
  final int intervalDays;
  final double discount;

  bool get isRecurring => this != Recurrence.none;
}

enum LedgerType {
  gcashRelease('GCash payout'),
  cashCommissionDue('Commission due (cash job)'),
  settlement('Commission settled'),
  refund('Refund');

  const LedgerType(this.label);
  final String label;
}

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
