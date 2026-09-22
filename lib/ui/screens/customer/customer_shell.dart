import 'package:flutter/material.dart';

import '../shared/account_screen.dart';
import '../shared/notifications_screen.dart';
import 'customer_bookings_screen.dart';
import 'customer_home_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            CustomerHomeScreen(
                onSeeBookings: () => setState(() => _index = 1)),
            const CustomerBookingsScreen(),
            const NotificationsScreen(),
            const AccountScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.event_note_outlined),
                activeIcon: Icon(Icons.event_note_rounded),
                label: 'Bookings'),
            BottomNavigationBarItem(
                icon: const NotificationBadgeIcon(),
                activeIcon: const NotificationBadgeIcon(selected: true),
                label: 'Alerts'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Account'),
          ],
        ),
      );
}
