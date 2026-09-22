/// Business rules for the marketplace. Everything the pricing, commission and
/// settlement logic depends on lives here so it can be tuned in one place.
class Business {
  Business._();

  /// Platform commission kept from each completed booking, by tier.
  /// Company bookings are larger, so the rate is higher.
  static const double commissionIndividual = 0.10;
  static const double commissionCompany = 0.15;

  /// Once a provider owes this much commission from cash jobs, new bookings
  /// pause until they settle.
  static const double unsettledCommissionCap = 1500;

  /// Default starting rates (regular clean of a studio) when the customer has
  /// not picked a specific provider yet.
  static const double defaultBaseRateIndividual = 500;
  static const double defaultBaseRateCompany = 800;

  /// Firestore `whereIn` accepts at most 30 values, and providers are matched
  /// to requests with `barangayCode in serviceAreas`.
  static const int maxServiceAreas = 30;

  /// Davao City in the PSGC.
  static const String davaoRegionCode = '110000000';
  static const String davaoProvinceCode = '112400000';
  static const String davaoCityCode = '112402000';
}

const List<String> kTimeSlots = [
  '8:00 AM',
  '10:00 AM',
  '1:00 PM',
  '3:00 PM',
];
