import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/provider_profile.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/marketplace.dart';
import '../shared/booking_detail_screen.dart';
import '../shared/provider_profile_screen.dart';
import 'booking_flow_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.onSeeBookings});
  final VoidCallback onSeeBookings;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  TierFilter _tier = TierFilter.any;

  void _book({ServiceType? service}) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingFlowScreen(service: service)));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final backend = context.read<Backend>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [LinisColors.brand, LinisColors.brandDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          color: LinisColors.mint, size: 18),
                      const SizedBox(width: 4),
                      Text('Davao City',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Hi ${session.user?.firstName ?? ''}!',
                      style: text.headlineSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  Text('What needs cleaning today?',
                      style: text.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 18),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _book,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                color: LinisColors.brand),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Book a cleaning',
                                  style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 16)),
                            ),
                            const Icon(Icons.arrow_forward_rounded,
                                color: LinisColors.brand),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActiveBooking(onSeeAll: widget.onSeeBookings),
                  const SectionTitle('Services'),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 118,
                    ),
                    children: [
                      for (final s in ServiceType.values)
                        _ServiceTile(
                          service: s,
                          fromPrice: backend.pricing.quote(
                              baseRate: s.companyOnly
                                  ? ProviderTier.company.defaultBaseRate
                                  : ProviderTier.individual.defaultBaseRate,
                              service: s,
                              size: HomeSize.studio),
                          onTap: () => _book(service: s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle('Top-rated in Davao'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in TierFilter.values) ...[
                          ChoiceChip(
                            label: Text(t == TierFilter.any ? 'All' : t.label),
                            selected: _tier == t,
                            onSelected: (_) => setState(() => _tier = t),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          StreamBuilder<List<ProviderProfile>>(
            stream: backend.providers.watchApproved(tier: _tier),
            builder: (context, snap) {
              final list = snap.data ?? const [];
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => ProviderCard(
                    provider: list[i],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            ProviderProfileScreen(providerId: list[i].uid))),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.fromPrice,
    required this.onTap,
  });
  final ServiceType service;
  final double fromPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(serviceIcon(service), color: scheme.primary),
              ),
              const Spacer(),
              Text(service.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('from ${peso(fromPrice)}',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveBooking extends StatelessWidget {
  const _ActiveBooking({required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final uid = context.read<SessionController>().uid;
    return StreamBuilder<List<Booking>>(
      stream: backend.bookings.watchForCustomer(uid),
      builder: (context, snap) {
        final active =
            (snap.data ?? const <Booking>[]).where((b) => b.status.isActive).toList()
              ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        if (active.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Upcoming',
                trailing: active.length > 1
                    ? TextButton(
                        onPressed: onSeeAll,
                        child: Text('See all ${active.length}'))
                    : null,
              ),
              BookingCard(
                booking: active.first,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailScreen(bookingId: active.first.id))),
              ),
            ],
          ),
        );
      },
    );
  }
}
