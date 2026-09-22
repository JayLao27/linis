/// A PSGC place (region, province, city/municipality or barangay).
class PsgcPlace {
  const PsgcPlace({required this.code, required this.name});

  final String code;
  final String name;

  factory PsgcPlace.fromJson(Map<String, dynamic> json) => PsgcPlace(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) => other is PsgcPlace && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// A service address. Region → province → city → barangay come from the PSGC
/// API; the barangay code is what bookings are matched on.
class Address {
  const Address({
    required this.region,
    required this.province,
    required this.city,
    required this.barangay,
    required this.street,
  });

  final PsgcPlace region;
  final PsgcPlace? province;
  final PsgcPlace city;
  final PsgcPlace barangay;

  /// House number, street, building, landmark.
  final String street;

  String get shortLabel => '${barangay.name}, ${city.name}';

  String get fullLabel => [
        street,
        barangay.name,
        city.name,
        province?.name,
      ].where((s) => s != null && s.isNotEmpty).join(', ');

  factory Address.fromMap(Map<String, dynamic> map) {
    PsgcPlace place(String prefix) => PsgcPlace(
          code: map['${prefix}Code'] as String? ?? '',
          name: map['${prefix}Name'] as String? ?? '',
        );
    return Address(
      region: place('region'),
      province: map['provinceCode'] == null ? null : place('province'),
      city: place('city'),
      barangay: place('barangay'),
      street: map['street'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'regionCode': region.code,
        'regionName': region.name,
        'provinceCode': province?.code,
        'provinceName': province?.name,
        'cityCode': city.code,
        'cityName': city.name,
        'barangayCode': barangay.code,
        'barangayName': barangay.name,
        'street': street,
      };
}
