import '../models/enums.dart';
import '../models/provider_profile.dart';

class PriceRange {
  const PriceRange(this.min, this.max);
  final double min;
  final double max;
}

class CommissionSplit {
  const CommissionSplit({
    required this.rate,
    required this.commission,
    required this.providerShare,
  });
  final double rate;
  final double commission;
  final double providerShare;
}

/// Pure pricing and commission math, shared by the booking flow (live
/// estimate) and the repositories (the price fixed when a provider accepts).
class PricingService {
  const PricingService();

  /// Every quote is the provider's base rate scaled by service and home size,
  /// rounded to the nearest ₱10.
  double quote({
    required double baseRate,
    required ServiceType service,
    required HomeSize size,
  }) =>
      _round10(baseRate * service.multiplier * size.multiplier);

  double quoteFor(ProviderProfile p, ServiceType service, HomeSize size) =>
      quote(baseRate: p.baseRate, service: service, size: size);

  /// Estimate shown before the customer picks anyone: the spread of quotes
  /// from providers who could take the job, or the platform defaults for the
  /// allowed tiers when nobody matching is registered yet.
  PriceRange estimate({
    required ServiceType service,
    required HomeSize size,
    required TierFilter tierFilter,
    Iterable<ProviderProfile> candidates = const [],
  }) {
    final quotes = candidates.map((p) => quoteFor(p, service, size)).toList();
    if (quotes.isEmpty) {
      quotes.addAll(ProviderTier.values
          .where((t) => tierFilter.allows(t))
          .where((t) => !service.companyOnly || t == ProviderTier.company)
          .map((t) =>
              quote(baseRate: t.defaultBaseRate, service: service, size: size)));
    }
    quotes.sort();
    return PriceRange(quotes.first, quotes.last);
  }

  /// Rate range shown on a company profile: the cheapest job it offers
  /// (smallest home) up to the most expensive one (largest home).
  PriceRange profileRange(ProviderProfile p) {
    final services =
        p.servicesOffered.isEmpty ? [ServiceType.regular] : p.servicesOffered;
    final mults = services.map((s) => s.multiplier).toList()..sort();
    return PriceRange(
      _round10(p.baseRate * mults.first * HomeSize.values.first.multiplier),
      _round10(p.baseRate * mults.last * HomeSize.values.last.multiplier),
    );
  }

  CommissionSplit split(double price, ProviderTier tier) {
    final rate = tier.commissionRate;
    final commission = (price * rate * 100).round() / 100;
    return CommissionSplit(
      rate: rate,
      commission: commission,
      providerShare: price - commission,
    );
  }

  double _round10(double v) => (v / 10).round() * 10.0;
}
