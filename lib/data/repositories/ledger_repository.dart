import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/format.dart';
import '../models/enums.dart';
import '../models/ledger_entry.dart';
import 'booking_repository.dart';
import 'notification_repository.dart';

/// Provider payouts and the weekly settlement of commission from cash jobs.
class LedgerRepository {
  LedgerRepository(this._db, this._notifications);
  final FirebaseFirestore _db;
  final NotificationRepository _notifications;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('ledger');

  Stream<List<LedgerEntry>> watchForProvider(String providerId) => _col
      .where('providerId', isEqualTo: providerId)
      .snapshots()
      .map((s) => s.docs.map((d) => LedgerEntry.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  /// Everything on the ledger, for the admin's commission totals.
  Stream<List<LedgerEntry>> watchAll() => _col.snapshots().map(
      (s) => s.docs.map((d) => LedgerEntry.fromMap(d.id, d.data())).toList());

  /// Clears what a provider owes, which lifts a bookings pause. Called after
  /// the provider pays through GCash, or by an admin who received it in person.
  /// Returns the amount settled.
  Future<double> settle(String providerId, {required String reference}) async {
    final amount = await _db.runTransaction((tx) async {
      final pRef = _db.collection('providers').doc(providerId);
      final snap = await tx.get(pRef);
      final owed = (snap.data()?['unsettledCommission'] as num? ?? 0).toDouble();
      if (owed <= 0) throw BookingException('Nothing to settle.');
      tx.update(pRef, {'unsettledCommission': 0});
      tx.set(
          _col.doc(),
          LedgerEntry.newDoc(
            providerId: providerId,
            type: LedgerType.settlement,
            amount: owed,
            reference: reference,
          ));
      return owed;
    });
    await _notifications.notify(
      userId: providerId,
      title: 'Commission settled',
      body: '${peso(amount)} received. Thank you! New bookings are open.',
    );
    return amount;
  }

  /// Monday of next week: when the weekly settlement is due.
  static DateTime nextSettlementDue([DateTime? from]) {
    final d = from ?? DateTime.now();
    final daysToMonday = (DateTime.monday - d.weekday + 7) % 7;
    return DateTime(d.year, d.month, d.day)
        .add(Duration(days: daysToMonday == 0 ? 7 : daysToMonday));
  }
}
