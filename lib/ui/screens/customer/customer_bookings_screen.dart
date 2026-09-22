import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/models/booking.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/marketplace.dart';
import '../shared/booking_detail_screen.dart';
import 'booking_flow_screen.dart';

class CustomerBookingsScreen extends StatelessWidget {
  const CustomerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final uid = context.read<SessionController>().uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My bookings'),
          bottom: const TabBar(tabs: [Tab(text: 'Active'), Tab(text: 'History')]),
        ),
        body: StreamBuilder<List<Booking>>(
          stream: backend.bookings.watchForCustomer(uid),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!;
            final active = all.where((b) => b.status.isActive).toList();
            final past = all.where((b) => !b.status.isActive).toList();
            return TabBarView(
              children: [
                _List(
                  bookings: active,
                  empty: EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'No active bookings',
                    message: 'Book a verified cleaner in under a minute.',
                    action: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const BookingFlowScreen())),
                      child: const Text('Book a cleaning'),
                    ),
                  ),
                ),
                _List(
                  bookings: past,
                  empty: const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No past bookings',
                    message: 'Completed and cancelled jobs appear here with '
                        'their dates and amounts.',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.bookings, required this.empty});
  final List<Booking> bookings;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return empty;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => BookingCard(
        booking: bookings[i],
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BookingDetailScreen(bookingId: bookings[i].id))),
      ),
    );
  }
}
