import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import 'enums.dart';
import 'firestore_utils.dart';

/// `providers/{uid}`: the public marketplace profile of a cleaner or company.
///
/// [tier] decides which fields are filled in, which documents onboarding asks
/// for, and which profile layout the app renders.
class ProviderProfile {
  const ProviderProfile({
    required this.uid,
    required this.tier,
    required this.displayName,
    this.photoUrl,
    this.bio = '',
    this.phone = '',
    this.verificationStatus = VerificationStatus.incomplete,
    this.rejectionReason,
    this.serviceAreas = const [],
    this.serviceAreaNames = const [],
    this.servicesOffered = const [],
    this.baseRate = 0,
    // Company
    this.businessName,
    this.businessRegNo,
    this.permitUrl,
    this.crewSize = 0,
    this.equipment = const [],
    // Individual
    this.govIdType,
    this.govIdUrl,
    this.yearsExperience = 0,
    // Reputation & money
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.completedJobs = 0,
    this.unsettledCommission = 0,
    this.totalEarnings = 0,
    this.createdAt,
  });

  final String uid;
  final ProviderTier tier;
  final String displayName;
  final String? photoUrl;
  final String bio;
  final String phone;
  final VerificationStatus verificationStatus;
  final String? rejectionReason;

  /// PSGC barangay codes this provider accepts jobs in.
  final List<String> serviceAreas;
  final List<String> serviceAreaNames;
  final List<ServiceType> servicesOffered;

  /// Price of a regular clean of a studio. Every quote scales from this.
  final double baseRate;

  final String? businessName;
  final String? businessRegNo;
  final String? permitUrl;
  final int crewSize;
  final List<String> equipment;

  final String? govIdType;
  final String? govIdUrl;
  final int yearsExperience;

  final double ratingAvg;
  final int ratingCount;
  final int completedJobs;

  /// Commission owed to Linis from cash jobs, cleared by weekly settlement.
  final double unsettledCommission;
  final double totalEarnings;
  final DateTime? createdAt;

  bool get isCompany => tier == ProviderTier.company;
  bool get isApproved => verificationStatus == VerificationStatus.approved;

  bool get bookingsPaused =>
      unsettledCommission >= Business.unsettledCommissionCap;

  /// Can this provider take a new job right now?
  bool get canAcceptJobs => isApproved && !bookingsPaused;

  bool offers(ServiceType type) => servicesOffered.contains(type);

  bool covers(String barangayCode) => serviceAreas.contains(barangayCode);

  factory ProviderProfile.fromMap(String uid, Map<String, dynamic> map) =>
      ProviderProfile(
        uid: uid,
        tier: enumByName(
            ProviderTier.values, map['tier'], ProviderTier.individual),
        displayName: map['displayName'] as String? ?? '',
        photoUrl: map['photoUrl'] as String?,
        bio: map['bio'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        verificationStatus: enumByName(VerificationStatus.values,
            map['verificationStatus'], VerificationStatus.incomplete),
        rejectionReason: map['rejectionReason'] as String?,
        serviceAreas: readStringList(map['serviceAreas']),
        serviceAreaNames: readStringList(map['serviceAreaNames']),
        servicesOffered: readStringList(map['servicesOffered'])
            .map((s) => enumByName(ServiceType.values, s, ServiceType.regular))
            .toSet()
            .toList(),
        baseRate: readDouble(map['baseRate']),
        businessName: map['businessName'] as String?,
        businessRegNo: map['businessRegNo'] as String?,
        permitUrl: map['permitUrl'] as String?,
        crewSize: readInt(map['crewSize']),
        equipment: readStringList(map['equipment']),
        govIdType: map['govIdType'] as String?,
        govIdUrl: map['govIdUrl'] as String?,
        yearsExperience: readInt(map['yearsExperience']),
        ratingAvg: readDouble(map['ratingAvg']),
        ratingCount: readInt(map['ratingCount']),
        completedJobs: readInt(map['completedJobs']),
        unsettledCommission: readDouble(map['unsettledCommission']),
        totalEarnings: readDouble(map['totalEarnings']),
        createdAt: readDate(map['createdAt']),
      );

  /// Fields the provider edits during onboarding. Rating and money fields are
  /// left out on purpose: they only change through bookings and reviews.
  Map<String, dynamic> toEditableMap() => {
        'tier': tier.name,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'bio': bio,
        'phone': phone,
        'serviceAreas': serviceAreas,
        'serviceAreaNames': serviceAreaNames,
        'servicesOffered': servicesOffered.map((s) => s.name).toList(),
        'baseRate': baseRate,
        'businessName': businessName,
        'businessRegNo': businessRegNo,
        'permitUrl': permitUrl,
        'crewSize': crewSize,
        'equipment': equipment,
        'govIdType': govIdType,
        'govIdUrl': govIdUrl,
        'yearsExperience': yearsExperience,
      };

  Map<String, dynamic> toNewDocMap() => {
        ...toEditableMap(),
        'verificationStatus': verificationStatus.name,
        'ratingAvg': 0,
        'ratingCount': 0,
        'completedJobs': 0,
        'unsettledCommission': 0,
        'totalEarnings': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

  ProviderProfile copyWith({
    ProviderTier? tier,
    String? displayName,
    String? photoUrl,
    String? bio,
    String? phone,
    List<String>? serviceAreas,
    List<String>? serviceAreaNames,
    List<ServiceType>? servicesOffered,
    double? baseRate,
    String? businessName,
    String? businessRegNo,
    String? permitUrl,
    int? crewSize,
    List<String>? equipment,
    String? govIdType,
    String? govIdUrl,
    int? yearsExperience,
  }) =>
      ProviderProfile(
        uid: uid,
        tier: tier ?? this.tier,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        bio: bio ?? this.bio,
        phone: phone ?? this.phone,
        verificationStatus: verificationStatus,
        rejectionReason: rejectionReason,
        serviceAreas: serviceAreas ?? this.serviceAreas,
        serviceAreaNames: serviceAreaNames ?? this.serviceAreaNames,
        servicesOffered: servicesOffered ?? this.servicesOffered,
        baseRate: baseRate ?? this.baseRate,
        businessName: businessName ?? this.businessName,
        businessRegNo: businessRegNo ?? this.businessRegNo,
        permitUrl: permitUrl ?? this.permitUrl,
        crewSize: crewSize ?? this.crewSize,
        equipment: equipment ?? this.equipment,
        govIdType: govIdType ?? this.govIdType,
        govIdUrl: govIdUrl ?? this.govIdUrl,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
        completedJobs: completedJobs,
        unsettledCommission: unsettledCommission,
        totalEarnings: totalEarnings,
        createdAt: createdAt,
      );
}
