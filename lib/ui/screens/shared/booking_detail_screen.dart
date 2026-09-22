import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/recurring_plan.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../state/session_controller.dart';
import '../../theme.dart';
import '../../widgets/booking_actions.dart';
import '../../widgets/common.dart';
import '../../widgets/marketplace.dart';
import '../../widgets/sheets.dart';
import 'provider_profile_screen.dart';

/// One booking, from the customer's or the provider's side. The action bar at
/// the bottom only offers what the viewer can do in the current state.
class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder<Booking?>(
      stream: backend.bookings.watch(bookingId),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Booking not found'),
          );
        }
        return _BookingDetailView(booking: b);
      },
    );
  }
}

class _BookingDetailView extends StatelessWidget {
  const _BookingDetailView({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final b = booking;
    final isCustomer = session.uid == b.customerId;
    final isProvider = session.user?.role == UserRole.provider;
    final scheme = Theme.of(context).colorScheme;
    // A provider looking at an open request sees their own quote.
    final myQuote = isProvider && b.price == null && session.provider != null
        ? context
            .read<Backend>()
            .pricing
            .quoteFor(
                session.provider!, b.serviceType, b.homeSize, b.recurrence)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(b.serviceType.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.price != null
                              ? peso(b.price!)
                              : myQuote != null
                                  ? peso(myQuote)
                                  : pesoRange(b.estimateMin, b.estimateMax),
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ),
                      StatusChip(b.status, forProvider: !isCustomer),
                    ],
                  ),
                  Text(
                      b.price != null
                          ? 'Final price'
                          : myQuote != null
                              ? 'Your price for this job'
                              : 'Estimated price',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  _Timeline(booking: b),
                ],
              ),
            ),
          ),
          if (b.isRecurring) ...[
            const SizedBox(height: 12),
            _PlanSection(booking: b),
          ],
          const SizedBox(height: 12),
          if (isCustomer) _ProviderSection(booking: b) else _CustomerSection(booking: b),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Job details'),
                  InfoRow(
                      icon: Icons.event_rounded,
                      label: 'Schedule',
                      value: '${formatDate(b.scheduledDate)}\n${b.timeSlot}'),
                  InfoRow(
                      icon: Icons.home_work_outlined,
                      label: 'Home size',
                      value: b.homeSize.label),
                  InfoRow(
                      icon: Icons.place_outlined,
                      label: 'Address',
                      value: b.address.fullLabel),
                  if (b.notes.isNotEmpty)
                    InfoRow(
                        icon: Icons.sticky_note_2_outlined,
                        label: 'Notes',
                        value: b.notes),
                  if (b.providerId == null)
                    InfoRow(
                        icon: Icons.filter_alt_outlined,
                        label: 'Open to',
                        value: b.isDirect
                            ? 'Your chosen cleaner'
                            : b.tierFilter.label),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PaymentSection(booking: b, forProvider: isProvider),
          if (b.status == BookingStatus.cancelled) ...[
            const SizedBox(height: 12),
            NoticeBanner(
              icon: Icons.cancel_outlined,
              color: LinisColors.danger,
              text: 'Cancelled by '
                  '${b.cancelledBy == b.customerId ? 'the customer' : 'the cleaner'}'
                  '${(b.cancelReason ?? '').isNotEmpty ? ': "${b.cancelReason}"' : '.'}',
            ),
          ],
        ],
      ),
      bottomNavigationBar: _ActionBar(booking: b, isCustomer: isCustomer),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final gcash = b.paymentMethod == PaymentMethod.gcash;
    final steps = <(String, bool)>[
      ('Requested', true),
      ('Accepted', b.providerId != null),
      if (gcash)
        ('Paid', b.paymentStatus != PaymentStatus.unpaid),
      ('Cleaning', b.status.index >= BookingStatus.inProgress.index &&
          b.status != BookingStatus.cancelled),
      ('Done', b.status == BookingStatus.completed),
    ];
    final scheme = Theme.of(context).colorScheme;
    final cancelled = b.status == BookingStatus.cancelled;

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                          height: 3,
                          color: i == 0
                              ? Colors.transparent
                              : steps[i].$2
                                  ? scheme.primary
                                  : scheme.outlineVariant),
                    ),
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: steps[i].$2
                          ? (cancelled ? LinisColors.danger : scheme.primary)
                          : scheme.surfaceContainerHighest,
                      child: Icon(
                        steps[i].$2 ? Icons.check_rounded : Icons.circle,
                        size: steps[i].$2 ? 14 : 6,
                        color: steps[i].$2
                            ? Colors.white
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Container(
                          height: 3,
                          color: i == steps.length - 1
                              ? Colors.transparent
                              : (i + 1 < steps.length && steps[i + 1].$2)
                                  ? scheme.primary
                                  : scheme.outlineVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(steps[i].$1,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            steps[i].$2 ? FontWeight.w600 : FontWeight.w400,
                        color: steps[i].$2
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProviderSection extends StatelessWidget {
  const _ProviderSection({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final backend = context.read<Backend>();
    if (b.providerId == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: b.status == BookingStatus.cancelled
              ? const Text('No cleaner was assigned.')
              : StreamBuilder(
                  stream: backend.providers.watchMatching(
                      barangayCode: b.barangayCode,
                      service: b.serviceType,
                      tierFilter: b.tierFilter),
                  builder: (context, snap) {
                    final n = snap.data?.length ?? 0;
                    return Row(
                      children: [
                        const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            b.isDirect
                                ? 'Waiting for your chosen cleaner to accept. '
                                    "If they can't, we'll send it to others nearby."
                                : 'Sent to $n cleaner${n == 1 ? '' : 's'} in '
                                    '${b.address.barangay.name}. You\'ll be '
                                    'notified when one accepts.',
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      );
    }
    return StreamBuilder(
      stream: backend.providers.watch(b.providerId!),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return const SizedBox.shrink();
        return ProviderCard(
          provider: p,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  ProviderProfileScreen(providerId: p.uid, showBookButton: false))),
        );
      },
    );
  }
}

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder(
      stream: backend.users.watch(booking.customerId),
      builder: (context, snap) {
        final c = snap.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Avatar(name: booking.customerName, url: c?.photoUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      if (c != null)
                        RatingBadge(avg: c.ratingAvg, count: c.ratingCount),
                    ],
                  ),
                ),
                // Contact details only once the job is yours.
                if (booking.providerId != null &&
                    booking.status.isActive &&
                    booking.customerPhone.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.phone_rounded, size: 18),
                      Text(booking.customerPhone,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.booking, required this.forProvider});
  final Booking booking;
  final bool forProvider;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Payment'),
            InfoRow(
                icon: b.paymentMethod == PaymentMethod.gcash
                    ? Icons.account_balance_wallet_outlined
                    : Icons.payments_outlined,
                label: 'Method',
                value: b.paymentMethod.label),
            InfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'Status',
                value: b.paymentStatus.label),
            if (b.paymentRef != null)
              InfoRow(icon: Icons.tag, label: 'Reference', value: b.paymentRef!),
            if (forProvider && b.price != null) ...[
              const Divider(height: 24),
              InfoRow(
                  icon: Icons.sell_outlined,
                  label: 'Job price',
                  value: peso(b.price!)),
              InfoRow(
                  icon: Icons.percent_rounded,
                  label: 'Linis fee',
                  value:
                      '− ${peso(b.commissionAmount ?? 0)} (${((b.commissionRate ?? 0) * 100).round()}%)'),
              InfoRow(
                  icon: Icons.savings_outlined,
                  label: 'You earn',
                  value: peso(b.providerShare ?? 0),
                  bold: true),
              if (b.paymentMethod == PaymentMethod.cash)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Collect ${peso(b.price!)} in cash. The Linis fee is added '
                    'to your weekly settlement.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.booking, required this.isCustomer});
  final Booking booking;
  final bool isCustomer;

  @override
  Widget build(BuildContext context) {
    final actions = isCustomer
        ? _customerActions(context)
        : _providerActions(context);
    if (actions.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(flex: i == actions.length - 1 ? 2 : 1, child: actions[i]),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _customerActions(BuildContext context) {
    final b = booking;
    final backend = context.read<Backend>();
    final session = context.read<SessionController>();
    final cancel = AsyncButton(
      label: 'Cancel',
      outlined: true,
      color: LinisColors.danger,
      onPressed: () => _cancel(context),
    );

    switch (b.status) {
      case BookingStatus.pending:
        return [cancel];
      case BookingStatus.accepted:
        if (b.paymentMethod == PaymentMethod.gcash &&
            b.paymentStatus == PaymentStatus.unpaid) {
          return [
            cancel,
            AsyncButton(
              label: 'Pay ${peso(b.price!)}',
              icon: Icons.account_balance_wallet_rounded,
              onPressed: () async {
                final ref = await showGcashSheet(context,
                    amount: b.price!,
                    description: '${b.serviceType.label} · ${b.providerName}',
                    initialNumber: session.user?.phone);
                if (ref == null || !context.mounted) return;
                await runGuarded(
                    context, () => backend.bookings.recordGcashPayment(b.id, ref),
                    success: 'Payment received. Linis holds it until the job is done.');
              },
            ),
          ];
        }
        return [cancel];
      case BookingStatus.awaitingConfirmation:
        final cash = b.paymentMethod == PaymentMethod.cash;
        return [
          AsyncButton(
            label: cash ? 'Paid in cash · Confirm job' : 'Confirm job is done',
            icon: Icons.task_alt_rounded,
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Confirm the job is done?',
                  message: cash
                      ? 'Confirm that the cleaning is finished and you paid '
                          '${peso(b.displayPrice)} in cash.'
                      : 'Your GCash payment of ${peso(b.displayPrice)} will be '
                          'released to ${b.providerName}.',
                  confirmLabel: 'Confirm');
              if (!ok || !context.mounted) return;
              final done = await runGuarded(context,
                  () => backend.bookings.confirmCompletion(b.id, session.uid));
              if (done && context.mounted) await _rate(context);
            },
          ),
        ];
      case BookingStatus.completed:
        if (!b.customerRated) {
          return [
            AsyncButton(
                label: 'Rate ${b.providerName}',
                icon: Icons.star_rounded,
                onPressed: () => _rate(context)),
          ];
        }
        return const [];
      case BookingStatus.inProgress:
      case BookingStatus.cancelled:
        return const [];
    }
  }

  List<Widget> _providerActions(BuildContext context) {
    final b = booking;
    final backend = context.read<Backend>();
    final session = context.read<SessionController>();
    final me = session.provider;
    if (me == null) return const [];

    if (b.status == BookingStatus.pending && b.providerId == null) {
      return [
        AsyncButton(
          label: 'Decline',
          outlined: true,
          onPressed: () async {
            final ok = await runGuarded(
                context, () => backend.bookings.decline(b.id, me.uid));
            if (ok && context.mounted) Navigator.of(context).pop();
          },
        ),
        AsyncButton(
          label: '${b.isRecurring ? 'Accept plan' : 'Accept'} · '
              '${peso(backend.pricing.quoteFor(me, b.serviceType, b.homeSize, b.recurrence))}',
          icon: Icons.check_rounded,
          onPressed:
              me.canAcceptJobs ? () => acceptJob(context, b, me) : null,
        ),
      ];
    }
    if (b.providerId != me.uid) return const [];

    switch (b.status) {
      case BookingStatus.accepted:
        return [
          AsyncButton(
            label: 'Cancel',
            outlined: true,
            color: LinisColors.danger,
            onPressed: () => _cancel(context),
          ),
          AsyncButton(
            label: b.readyToStart ? 'Start job' : 'Waiting for payment',
            icon: Icons.play_arrow_rounded,
            onPressed: b.readyToStart
                ? () => runGuarded(
                    context, () => backend.bookings.start(b.id, me.uid))
                : null,
          ),
        ];
      case BookingStatus.inProgress:
        return [
          AsyncButton(
            label: 'Mark job as done',
            icon: Icons.task_alt_rounded,
            onPressed: () => runGuarded(
                context, () => backend.bookings.finish(b.id, me.uid),
                success: 'The customer was asked to confirm.'),
          ),
        ];
      case BookingStatus.completed:
        if (!b.providerRated) {
          return [
            AsyncButton(
                label: 'Rate ${b.customerName}',
                icon: Icons.star_rounded,
                onPressed: () => _rate(context)),
          ];
        }
        return const [];
      case BookingStatus.pending:
      case BookingStatus.awaitingConfirmation:
      case BookingStatus.cancelled:
        return const [];
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final backend = context.read<Backend>();
    final uid = context.read<SessionController>().uid;
    final b = booking;
    // A plan visit with a cleaner can be skipped without ending the plan.
    if (b.isRecurring &&
        b.providerId != null &&
        b.visitNumber < b.totalVisits) {
      final endPlan = await _askSkipOrEnd(context);
      if (endPlan == null || !context.mounted) return;
      await runGuarded(
        context,
        () => backend.bookings.cancel(b.id, uid,
            reason: endPlan ? 'Plan ended' : 'Visit skipped',
            endPlan: endPlan),
        success: endPlan ? 'Plan ended.' : 'Visit skipped. Next one is booked.',
      );
      return;
    }
    final reason = await textInputDialog(context,
        title: 'Cancel booking?',
        label: 'Reason (optional)',
        confirmLabel: 'Cancel booking',
        required: false);
    if (reason == null || !context.mounted) return;
    await runGuarded(
        context, () => backend.bookings.cancel(booking.id, uid, reason: reason),
        success: 'Booking cancelled.');
  }

  /// Returns true to end the plan, false to skip only this visit.
  Future<bool?> _askSkipOrEnd(BuildContext context) {
    final b = booking;
    final next = BookingRepository.nextVisitDate(b.scheduledDate, b.recurrence);
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Cancel this visit?',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
                title: const Text('Skip this visit only'),
                subtitle: Text('The plan continues. Next visit: '
                    '${formatDate(next)}, ${b.timeSlot}.'),
                onTap: () => Navigator.pop(ctx, false),
              ),
              ListTile(
                leading:
                    const Icon(Icons.stop_circle_outlined, color: LinisColors.danger),
                title: const Text('End the whole plan',
                    style: TextStyle(color: LinisColors.danger)),
                subtitle: Text('No more visits after this. '
                    '${b.paymentStatus == PaymentStatus.held ? 'This visit is refunded.' : ''}'),
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rate(BuildContext context) async {
    final backend = context.read<Backend>();
    final session = context.read<SessionController>();
    final b = booking;
    final result = await showRatingSheet(
      context,
      title: isCustomer ? 'How was ${b.providerName}?' : 'Rate ${b.customerName}',
      subtitle: isCustomer
          ? 'Your review helps other Davao households choose.'
          : 'Was the customer on time, clear and easy to work with?',
    );
    if (result == null || !context.mounted) return;
    await runGuarded(
      context,
      () => backend.reviews.submit(
        bookingId: b.id,
        direction: isCustomer
            ? ReviewDirection.customerToProvider
            : ReviewDirection.providerToCustomer,
        fromUid: session.uid,
        fromName: isCustomer
            ? session.user!.fullName
            : session.provider?.displayName ?? session.user!.fullName,
        rating: result.rating,
        comment: result.comment,
      ),
      success: 'Thanks for your rating!',
    );
  }
}

/// Recurring-plan summary on a visit. Participants see live plan status and
/// can end it; a provider looking at an open plan request sees the terms.
class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final session = context.read<SessionController>();
    final isParticipant =
        session.uid == b.customerId || session.uid == b.providerId;
    if (!isParticipant) return _card(context, null);
    return StreamBuilder<RecurringPlan?>(
      stream: context.read<Backend>().bookings.watchPlan(b.planId!),
      builder: (context, snap) => _card(context, snap.data),
    );
  }

  Widget _card(BuildContext context, RecurringPlan? plan) {
    final b = booking;
    final scheme = Theme.of(context).colorScheme;
    final session = context.read<SessionController>();
    final isCurrent = plan?.currentBookingId == b.id;
    final upcoming = plan != null && plan.active && isCurrent
        ? plan.upcomingDates(b.scheduledDate)
        : const <DateTime>[];
    final (statusText, statusColor) = plan == null
        ? ('Plan request', LinisColors.warning)
        : plan.active
            ? ('Active', LinisColors.success)
            : plan.endedBy == null
                ? ('Completed', LinisColors.brand)
                : ('Ended', LinisColors.danger);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Recurring plan',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            InfoRow(
                icon: Icons.repeat_rounded,
                label: 'Repeats',
                value: '${b.recurrence.label}, '
                    '${formatWeekday(b.scheduledDate)}s at ${b.timeSlot}'),
            InfoRow(
                icon: Icons.format_list_numbered_rounded,
                label: 'This visit',
                value: '${b.visitNumber} of ${b.totalVisits}'
                    '${plan != null ? ' · ${plan.completedVisits} done' : ''}'),
            InfoRow(
                icon: Icons.local_offer_outlined,
                label: 'Discount',
                value: '${(b.recurrence.discount * 100).round()}% off every visit'),
            if (upcoming.isNotEmpty)
              InfoRow(
                  icon: Icons.event_repeat_rounded,
                  label: 'Coming up',
                  value: upcoming.map(formatShortDate).join(', ') +
                      (plan!.totalVisits - plan.visitsCreated > upcoming.length
                          ? '…'
                          : '')),
            if (plan != null && !plan.active && plan.endedBy != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Ended by ${plan.endedBy == plan.customerId ? 'the customer' : 'the cleaner'} '
                  'after ${plan.completedVisits} of ${plan.totalVisits} visits.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
            if (plan != null && plan.active && isCurrent) ...[
              const SizedBox(height: 12),
              AsyncButton(
                label: 'End plan',
                icon: Icons.stop_circle_outlined,
                outlined: true,
                color: LinisColors.danger,
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: 'End this plan?',
                      message: 'No more visits will be booked. '
                          '${b.status == BookingStatus.pending || b.status == BookingStatus.accepted ? 'This visit is cancelled too.' : 'This visit still finishes.'}',
                      confirmLabel: 'End plan',
                      destructive: true);
                  if (!ok || !context.mounted) return;
                  await runGuarded(
                      context,
                      () => context
                          .read<Backend>()
                          .bookings
                          .endPlan(plan.id, session.uid),
                      success: 'Plan ended.');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
