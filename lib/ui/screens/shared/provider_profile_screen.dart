import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/provider_profile.dart';
import '../../../data/models/review.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/marketplace.dart';
import '../customer/booking_flow_screen.dart';

/// Public profile. Companies show registration, crew, equipment and a rate
/// range; individuals show their verified ID, experience and per-job rate.
class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({
    super.key,
    required this.providerId,
    this.showBookButton = true,
  });
  final String providerId;
  final bool showBookButton;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final isCustomer =
        context.read<SessionController>().user?.role == UserRole.customer;

    return StreamBuilder<ProviderProfile?>(
      stream: backend.providers.watch(providerId),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 230,
                backgroundColor: LinisColors.brand,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: _Header(provider: p),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(children: [
                  if (p.bio.isNotEmpty) ...[
                    Text(p.bio, style: const TextStyle(height: 1.45)),
                    const SizedBox(height: 16),
                  ],
                  _StatsRow(provider: p),
                  const SizedBox(height: 16),
                  if (p.isCompany)
                    _CompanyDetails(provider: p)
                  else
                    _IndividualDetails(provider: p),
                  const SizedBox(height: 16),
                  _ServicesCard(provider: p),
                  const SizedBox(height: 8),
                  _Reviews(providerId: p.uid),
                ]),
              ),
            ],
          ),
          bottomNavigationBar: showBookButton && isCustomer && p.isApproved
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text('Book ${p.isCompany ? 'this company' : p.displayName.split(' ').first}'),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => BookingFlowScreen(provider: p))),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider});
  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [LinisColors.brand, LinisColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Avatar(name: p.displayName, url: p.photoUrl, size: 76),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6)),
                      child: TierBadge(p.tier),
                    ),
                    if (p.isApproved)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: LinisColors.mint, size: 16),
                          SizedBox(width: 4),
                          Text('Verified',
                              style: TextStyle(
                                  color: LinisColors.mint,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.provider});
  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final pricing = context.read<Backend>().pricing;
    final range = pricing.profileRange(p);
    Widget stat(String value, String label, {IconData? icon}) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null)
                        Icon(icon, color: LinisColors.star, size: 18),
                      Flexible(
                        child: Text(value,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        stat(p.ratingCount == 0 ? 'New' : p.ratingAvg.toStringAsFixed(1),
            '${p.ratingCount} ratings',
            icon: p.ratingCount == 0 ? null : Icons.star_rounded),
        const SizedBox(width: 8),
        stat('${p.completedJobs}', 'jobs done'),
        const SizedBox(width: 8),
        stat(
          p.isCompany ? pesoRange(range.min, range.max) : peso(p.baseRate),
          p.isCompany ? 'rate range' : 'per job, from',
        ),
      ],
    );
  }
}

class _CompanyDetails extends StatelessWidget {
  const _CompanyDetails({required this.provider});
  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Company'),
            InfoRow(
              icon: Icons.verified_user_outlined,
              label: 'Registration',
              value: p.isApproved
                  ? 'Verified · ${p.businessRegNo ?? ''}'
                  : 'Pending verification',
            ),
            InfoRow(
                icon: Icons.groups_outlined,
                label: 'Crew size',
                value: '${p.crewSize} trained cleaners'),
            InfoRow(
                icon: Icons.map_outlined,
                label: 'Service areas',
                value: p.serviceAreaNames.join(', ')),
            if (p.equipment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Equipment',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: p.equipment
                    .map((e) => Chip(
                          label: Text(e),
                          avatar: const Icon(Icons.handyman_outlined, size: 16),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IndividualDetails extends StatelessWidget {
  const _IndividualDetails({required this.provider});
  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('About this cleaner'),
            InfoRow(
              icon: Icons.badge_outlined,
              label: 'Government ID',
              value: p.isApproved
                  ? 'Verified · ${p.govIdType ?? 'ID on file'}'
                  : 'Pending verification',
            ),
            InfoRow(
                icon: Icons.work_history_outlined,
                label: 'Experience',
                value:
                    '${p.yearsExperience} year${p.yearsExperience == 1 ? '' : 's'}'),
            InfoRow(
                icon: Icons.map_outlined,
                label: 'Service areas',
                value: p.serviceAreaNames.join(', ')),
            InfoRow(
                icon: Icons.sell_outlined,
                label: 'Per-job rate',
                value: '${peso(p.baseRate)} for a regular studio clean'),
          ],
        ),
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.provider});
  final ProviderProfile provider;

  @override
  Widget build(BuildContext context) {
    final pricing = context.read<Backend>().pricing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Services & starting prices'),
            for (final s in provider.servicesOffered)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(serviceIcon(s),
                        size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.label)),
                    Text(
                        'from ${peso(pricing.quote(baseRate: provider.baseRate, service: s, size: HomeSize.studio))}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.providerId});
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder<List<Review>>(
      stream: backend.reviews.watchFor(providerId),
      builder: (context, snap) {
        final reviews = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Reviews (${reviews.length})'),
            if (reviews.isEmpty)
              Text('No written reviews yet.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            for (final r in reviews) ...[
              ReviewTile(review: r),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: r.fromName, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.fromName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (r.createdAt != null)
                  Text(timeAgo(r.createdAt!),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            StarRow(rating: r.rating),
            if (r.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.comment, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}
