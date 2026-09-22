import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/booking.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/marketplace.dart';
import '../shared/booking_detail_screen.dart';

/// Open requests in the provider's barangays, newest schedule first.
class JobRequestsScreen extends StatelessWidget {
  const JobRequestsScreen({super.key, required this.onOpenEarnings});
  final VoidCallback onOpenEarnings;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final backend = context.read<Backend>();
    final me = session.provider!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job requests'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: RatingBadge(
                  avg: me.ratingAvg, count: me.ratingCount, compact: true),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (me.bookingsPaused)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: NoticeBanner(
                icon: Icons.pause_circle_outline_rounded,
                color: LinisColors.danger,
                text: 'New bookings are paused. You owe '
                    '${peso(me.unsettledCommission)} in commission from cash jobs.',
                action: TextButton(
                    onPressed: onOpenEarnings, child: const Text('Settle')),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Booking>>(
              // Keyed on areas so editing them restarts the query.
              key: ValueKey(me.serviceAreas.join(',')),
              stream: backend.bookings.watchOpenRequests(me),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'No open requests right now',
                    message: 'New requests from ${me.serviceAreaNames.take(3).join(', ')}'
                        '${me.serviceAreaNames.length > 3 ? ' and more' : ''} '
                        'will appear here and in your alerts.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final b = list[i];
                    final quote =
                        backend.pricing.quoteFor(me, b.serviceType, b.homeSize);
                    final share = quote - backend.pricing.split(quote, me.tier).commission;
                    return BookingCard(
                      booking: b,
                      forProvider: true,
                      priceOverride: quote,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BookingDetailScreen(bookingId: b.id))),
                      footer: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (b.requestedProviderId == me.uid)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: Text('Chose you'),
                                    avatar: Icon(Icons.favorite_rounded,
                                        size: 16, color: LinisColors.danger),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  '${b.homeSize.label} · ${b.paymentMethod.label}',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ),
                              Text('You earn ${peso(share)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: LinisColors.success)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: AsyncButton(
                                  label: 'Decline',
                                  outlined: true,
                                  onPressed: () => runGuarded(context,
                                      () => backend.bookings.decline(b.id, me.uid)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: AsyncButton(
                                  label: 'Accept · ${peso(quote)}',
                                  onPressed: me.canAcceptJobs
                                      ? () => runGuarded(
                                          context,
                                          () => backend.bookings
                                              .accept(b.id, me.uid),
                                          success:
                                              'Accepted! Find it under My jobs.')
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
