import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/backend.dart';
import '../../data/models/booking.dart';
import '../../data/models/provider_profile.dart';
import 'common.dart';
import 'sheets.dart';

/// Accepts a request. For a recurring plan the provider first confirms they
/// are committing to every visit.
Future<void> acceptJob(
    BuildContext context, Booking b, ProviderProfile me) async {
  final backend = context.read<Backend>();
  if (b.isRecurring) {
    final price = backend.pricing
        .quoteFor(me, b.serviceType, b.homeSize, b.recurrence);
    final ok = await confirmDialog(
      context,
      title: 'Accept a ${b.recurrence.label.toLowerCase()} plan?',
      message: '${b.totalVisits} visits with ${b.customerName}, '
          '${b.recurrence.label.toLowerCase()} on ${formatWeekday(b.scheduledDate)}s '
          'at ${b.timeSlot}, for ${peso(price)} per visit (plan discount '
          'included).\n\nEach next visit is booked for you automatically. You '
          'can skip a visit or end the plan if something comes up.',
      confirmLabel: 'Accept plan',
    );
    if (!ok || !context.mounted) return;
  }
  await runGuarded(
    context,
    () => backend.bookings.accept(b.id, me.uid),
    success: b.isRecurring
        ? 'Plan accepted. The first visit is under My jobs.'
        : 'Accepted! Find it under My jobs.',
  );
}
