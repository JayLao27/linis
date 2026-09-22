import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/models/booking.dart';
import '../../data/models/enums.dart';
import '../../data/models/provider_profile.dart';
import '../../state/session_controller.dart';
import '../theme.dart';
import 'common.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.avg,
    required this.count,
    this.compact = false,
  });
  final double avg;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (count == 0) {
      return Text('New', style: TextStyle(color: muted, fontSize: 13));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: LinisColors.star, size: 18),
        const SizedBox(width: 2),
        Text(avg.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Flexible(
          child: Text(
              compact ? ' ($count)' : ' · $count review${count == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 13)),
        ),
      ],
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 16});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            5,
            (i) => Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: LinisColors.star,
                )),
      );
}

class TierBadge extends StatelessWidget {
  const TierBadge(this.tier, {super.key});
  final ProviderTier tier;

  @override
  Widget build(BuildContext context) {
    final isCompany = tier == ProviderTier.company;
    final color = isCompany ? LinisColors.company : LinisColors.individual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCompany ? Icons.business_rounded : Icons.person_rounded,
              size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(tier.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) => const Tooltip(
        message: 'Documents checked by Linis',
        child: Icon(Icons.verified_rounded, size: 18, color: LinisColors.brand),
      );
}

Color statusColor(BookingStatus s) => switch (s) {
      BookingStatus.pending => LinisColors.warning,
      BookingStatus.accepted => LinisColors.brand,
      BookingStatus.inProgress => LinisColors.company,
      BookingStatus.awaitingConfirmation => LinisColors.company,
      BookingStatus.completed => LinisColors.success,
      BookingStatus.cancelled => LinisColors.danger,
    };

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.forProvider = false});
  final BookingStatus status;
  final bool forProvider;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final label = forProvider
        ? switch (status) {
            BookingStatus.pending => 'Open request',
            BookingStatus.awaitingConfirmation => 'Awaiting customer',
            _ => status.label,
          }
        : status.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

IconData serviceIcon(ServiceType s) => switch (s) {
      ServiceType.regular => Icons.cleaning_services_rounded,
      ServiceType.deep => Icons.bubble_chart_rounded,
      ServiceType.moveInOut => Icons.local_shipping_rounded,
      ServiceType.postConstruction => Icons.construction_rounded,
    };

/// Search result / list item for a provider. Shows the quote for the current
/// job when [quote] is given, otherwise the provider's starting rate.
class ProviderCard extends StatelessWidget {
  const ProviderCard({
    super.key,
    required this.provider,
    this.quote,
    this.onTap,
    this.selected = false,
    this.trailing,
  });

  final ProviderProfile provider;
  final double? quote;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = provider;
    final detail = p.isCompany
        ? '${p.crewSize}-person crew · ${p.completedJobs} jobs'
        : '${p.yearsExperience} yrs experience · ${p.completedJobs} jobs';
    return Card(
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.primary, width: 2))
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Avatar(name: p.displayName, url: p.photoUrl, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        if (p.isApproved) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TierBadge(p.tier),
                        RatingBadge(
                            avg: p.ratingAvg,
                            count: p.ratingCount,
                            compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(detail,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(quote != null ? peso(quote!) : 'from ${peso(p.baseRate)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: quote != null ? 16 : 13,
                              color: scheme.primary)),
                      if (quote != null)
                        Text('this job',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A booking in a list. [forProvider] swaps the counterpart shown.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.forProvider = false,
    this.onTap,
    this.footer,
    this.priceOverride,
  });

  final Booking booking;
  final bool forProvider;
  final VoidCallback? onTap;
  final Widget? footer;

  /// Shown instead of the booking's price, e.g. a provider's own quote on an
  /// open request.
  final double? priceOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = booking;
    final counterpart = forProvider
        ? b.customerName
        : (b.providerName ??
            (b.isDirect ? 'Waiting for your chosen cleaner' : 'Finding a cleaner…'));
    final price = priceOverride != null
        ? peso(priceOverride!)
        : b.price != null
            ? peso(b.price!)
            : pesoRange(b.estimateMin, b.estimateMax);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(serviceIcon(b.serviceType),
                        color: scheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.serviceType.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(counterpart,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, fontSize: 13)),
                        if (b.isRecurring)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(Icons.repeat_rounded,
                                    size: 14, color: scheme.primary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${b.recurrence.label} · visit '
                                    '${b.visitNumber} of ${b.totalVisits}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: scheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(b.status, forProvider: forProvider),
                      const SizedBox(height: 6),
                      Text(price,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${formatShortDate(b.scheduledDate)}, ${b.timeSlot}',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 14),
                  Icon(Icons.place_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(b.address.barangay.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              if (b.hasUnreadFor(context.read<SessionController>().uid)) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.mark_chat_unread_rounded,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('"${b.lastMessageText ?? ''}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: scheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
