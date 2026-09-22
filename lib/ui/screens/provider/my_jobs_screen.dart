import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/models/booking.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/marketplace.dart';
import '../shared/booking_detail_screen.dart';

class MyJobsScreen extends StatelessWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final uid = context.read<SessionController>().uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My jobs'),
          bottom:
              const TabBar(tabs: [Tab(text: 'Upcoming'), Tab(text: 'History')]),
        ),
        body: StreamBuilder<List<Booking>>(
          stream: backend.bookings.watchForProvider(uid),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!;
            final upcoming = all.where((b) => b.status.isActive).toList();
            final past = all.where((b) => !b.status.isActive).toList().reversed.toList();
            Widget list(List<Booking> items, Widget empty) => items.isEmpty
                ? empty
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => BookingCard(
                      booking: items[i],
                      forProvider: true,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              BookingDetailScreen(bookingId: items[i].id))),
                    ),
                  );
            return TabBarView(children: [
              list(
                  upcoming,
                  const EmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'No upcoming jobs',
                      message: 'Accept a request to see it here.')),
              list(
                  past,
                  const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No finished jobs yet')),
            ]);
          },
        ),
      ),
    );
  }
}
