import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/ledger_entry.dart';
import '../../../data/repositories/ledger_repository.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';

/// Earnings, commission owed from cash jobs, weekly settlement and the full
/// money history.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final backend = context.read<Backend>();
    final me = session.provider!;
    final scheme = Theme.of(context).colorScheme;
    final owed = me.unsettledCommission;
    final ratio = (owed / Business.unsettledCommissionCap).clamp(0.0, 1.0);
    final barColor = me.bookingsPaused
        ? LinisColors.danger
        : ratio > 0.7
            ? LinisColors.warning
            : scheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            color: LinisColors.brand,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total earned on Linis',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(peso(me.totalEarnings),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                      '${me.completedJobs} completed jobs · '
                      '${(me.tier.commissionRate * 100).round()}% Linis fee',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Commission owed',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text(peso(owed),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: barColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('From cash jobs. Due every Monday '
                      '(next: ${formatShortDate(LedgerRepository.nextSettlementDue())}).',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 10,
                      color: barColor,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    me.bookingsPaused
                        ? 'Limit of ${peso(Business.unsettledCommissionCap)} reached: '
                            'new bookings are paused until you settle.'
                        : 'New bookings pause at ${peso(Business.unsettledCommissionCap)}.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: me.bookingsPaused
                            ? LinisColors.danger
                            : scheme.onSurfaceVariant),
                  ),
                  if (owed > 0) ...[
                    const SizedBox(height: 14),
                    AsyncButton(
                      label: 'Settle ${peso(owed)} via GCash',
                      icon: Icons.account_balance_wallet_rounded,
                      onPressed: () async {
                        final ref = await showGcashSheet(context,
                            amount: owed,
                            description: 'Linis commission settlement',
                            initialNumber: me.phone);
                        if (ref == null || !context.mounted) return;
                        await runGuarded(context,
                            () => backend.ledger.settle(me.uid, reference: ref),
                            success: 'Settled. Thank you!');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SectionTitle('History'),
          StreamBuilder<List<LedgerEntry>>(
            stream: backend.ledger.watchForProvider(me.uid),
            builder: (context, snap) {
              final entries = snap.data ?? const [];
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Payouts and settlements will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                );
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _LedgerTile(entry: entries[i]),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final (icon, color, amountText, sub) = switch (e.type) {
      LedgerType.gcashRelease => (
          Icons.south_west_rounded,
          LinisColors.success,
          '+${peso(e.amount)}',
          'GCash payout · fee ${peso(e.commission)}'
        ),
      LedgerType.cashCommissionDue => (
          Icons.payments_outlined,
          LinisColors.warning,
          '+${peso(e.amount)}',
          'Cash job · ${peso(e.commission)} fee owed'
        ),
      LedgerType.settlement => (
          Icons.north_east_rounded,
          LinisColors.brand,
          '−${peso(e.amount)}',
          'Commission settled${e.reference != null ? ' · ref ${e.reference}' : ''}'
        ),
      LedgerType.refund => (
          Icons.undo_rounded,
          LinisColors.danger,
          peso(e.amount),
          'Refund'
        ),
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(e.type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${e.createdAt != null ? formatDateTime(e.createdAt!) : ''}\n$sub',
          style: const TextStyle(fontSize: 12.5)),
      isThreeLine: true,
      trailing: Text(amountText,
          style: TextStyle(fontWeight: FontWeight.w800, color: color)),
    );
  }
}
