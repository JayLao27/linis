import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/session_controller.dart';
import '../../theme.dart';
import 'provider_onboarding_screen.dart';

class ProviderPendingScreen extends StatelessWidget {
  const ProviderPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final p = session.provider!;
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      ('Account created', true),
      ('Documents submitted', true),
      ('Linis checks your ${p.isCompany ? 'permit & registration' : 'ID'}', false),
      ('Start receiving requests', false),
    ];

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: session.signOut),
      ]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: LinisColors.mint,
              child: Icon(Icons.hourglass_top_rounded,
                  size: 42, color: LinisColors.brand),
            ),
            const SizedBox(height: 20),
            Text('Your profile is under review',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'We check every document by hand, usually within 1–2 working '
              'days. You\'ll get a notification as soon as you\'re approved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (final (label, done) in steps)
                      ListTile(
                        leading: Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: done ? scheme.primary : scheme.outline,
                        ),
                        title: Text(label,
                            style: TextStyle(
                                fontWeight:
                                    done ? FontWeight.w600 : FontWeight.w400)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Review what I submitted'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      const ProviderOnboardingScreen(editing: true))),
            ),
          ],
        ),
      ),
    );
  }
}
