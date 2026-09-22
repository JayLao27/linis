import 'dart:math';

class PaymentResult {
  const PaymentResult({required this.success, this.reference, this.error});
  final bool success;
  final String? reference;
  final String? error;
}

/// Charges a GCash wallet. The customer pays into Linis's merchant account;
/// Linis holds the money until the job is confirmed.
///
/// A real integration goes through a PH payment provider (e.g. PayMongo's
/// GCash source) and needs a registered merchant account plus a server to
/// receive the payment webhook, so the app ships with [SimulatedGCashGateway].
abstract class PaymentGateway {
  Future<PaymentResult> charge({
    required double amount,
    required String description,
    required String mobileNumber,
  });
}

class SimulatedGCashGateway implements PaymentGateway {
  final _rng = Random();

  @override
  Future<PaymentResult> charge({
    required double amount,
    required String description,
    required String mobileNumber,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^(09|639)\d{9}$').hasMatch(digits)) {
      return const PaymentResult(
          success: false, error: 'Enter a valid GCash mobile number.');
    }
    final ref = List.generate(13, (_) => _rng.nextInt(10)).join();
    return PaymentResult(success: true, reference: ref);
  }
}
