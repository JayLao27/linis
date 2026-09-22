import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/backend.dart';
import '../../data/services/payment_gateway.dart';
import '../theme.dart';
import 'common.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: LinisColors.danger,
                    minimumSize: const Size(64, 44))
                : FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String confirmLabel = 'Submit',
  bool required = true,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () {
            if (required && controller.text.trim().isEmpty) return;
            Navigator.pop(ctx, controller.text.trim());
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Star rating + optional comment. Returns (rating, comment) or null.
Future<({int rating, String comment})?> showRatingSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
}) =>
    showModalBottomSheet<({int rating, String comment})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RatingSheet(title: title, subtitle: subtitle),
    );

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 0;
  final _comment = TextEditingController();

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  iconSize: 42,
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: LinisColors.star),
                );
              }),
            ),
            SizedBox(
              height: 22,
              child: Text(_labels[_rating],
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Write a review (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              onPressed: _rating == 0
                  ? null
                  : () => Navigator.pop(
                      context, (rating: _rating, comment: _comment.text)),
              child: const Text('Submit rating'),
            ),
          ],
        ),
      );
}

/// Collects a GCash number and charges it through the backend's payment
/// gateway. Returns the payment reference on success.
Future<String?> showGcashSheet(
  BuildContext context, {
  required double amount,
  required String description,
  String? initialNumber,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GcashSheet(
          amount: amount, description: description, initialNumber: initialNumber),
    );

class _GcashSheet extends StatefulWidget {
  const _GcashSheet({
    required this.amount,
    required this.description,
    this.initialNumber,
  });
  final double amount;
  final String description;
  final String? initialNumber;

  @override
  State<_GcashSheet> createState() => _GcashSheetState();
}

class _GcashSheetState extends State<_GcashSheet> {
  late final _number = TextEditingController(text: widget.initialNumber ?? '');
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final backend = context.read<Backend>();
    setState(() => _error = null);
    final result = await backend.payments.charge(
      amount: widget.amount,
      description: widget.description,
      mobileNumber: _number.text,
    );
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, result.reference);
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gcashBlue = Color(0xFF007DFE);
    final scheme = Theme.of(context).colorScheme;
    final simulated =
        context.read<Backend>().payments is SimulatedGCashGateway;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: gcashBlue,
                child: Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pay with GCash',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                    Text(widget.description,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Amount', style: TextStyle(color: scheme.onSurfaceVariant)),
          Text(peso(widget.amount),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'GCash mobile number',
              hintText: '09XX XXX XXXX',
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Linis holds your payment until you confirm the job is done.'
            '${simulated ? ' (Simulated payment: no real money moves.)' : ''}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          AsyncButton(
            label: 'Pay ${peso(widget.amount)}',
            icon: Icons.lock_rounded,
            color: gcashBlue,
            onPressed: _pay,
          ),
        ],
      ),
    );
  }
}
