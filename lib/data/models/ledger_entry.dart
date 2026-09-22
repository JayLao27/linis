import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'firestore_utils.dart';

/// `ledger/{id}`: every money movement between Linis and a provider, so both
/// sides keep a history with dates and amounts.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.providerId,
    required this.type,
    required this.amount,
    this.commission = 0,
    this.bookingId,
    this.reference,
    this.createdAt,
  });

  final String id;
  final String providerId;
  final LedgerType type;

  /// For payouts: what the provider received. For settlements: what they paid.
  final double amount;
  final double commission;
  final String? bookingId;
  final String? reference;
  final DateTime? createdAt;

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> map) =>
      LedgerEntry(
        id: id,
        providerId: map['providerId'] as String? ?? '',
        type: enumByName(LedgerType.values, map['type'], LedgerType.settlement),
        amount: readDouble(map['amount']),
        commission: readDouble(map['commission']),
        bookingId: map['bookingId'] as String?,
        reference: map['reference'] as String?,
        createdAt: readDate(map['createdAt']),
      );

  static Map<String, dynamic> newDoc({
    required String providerId,
    required LedgerType type,
    required double amount,
    double commission = 0,
    String? bookingId,
    String? reference,
  }) =>
      {
        'providerId': providerId,
        'type': type.name,
        'amount': amount,
        'commission': commission,
        'bookingId': bookingId,
        'reference': reference,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
