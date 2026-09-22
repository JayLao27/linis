import 'package:flutter/material.dart';

import '../shared/account_screen.dart';
import '../shared/notifications_screen.dart';
import 'earnings_screen.dart';
import 'job_requests_screen.dart';
import 'my_jobs_screen.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            JobRequestsScreen(onOpenEarnings: () => setState(() => _index = 2)),
            const MyJobsScreen(),
            const EarningsScreen(),
            const NotificationsScreen(),
            const AccountScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.inbox_outlined),
                activeIcon: Icon(Icons.inbox_rounded),
                label: 'Requests'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.work_outline_rounded),
                activeIcon: Icon(Icons.work_rounded),
                label: 'My jobs'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Earnings'),
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
