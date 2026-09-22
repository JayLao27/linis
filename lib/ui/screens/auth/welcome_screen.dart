import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/backend.dart';
import '../../../data/models/enums.dart';
import '../../theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDemo = context.read<Backend>().isDemo;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: LinisColors.brand,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.cleaning_services_rounded,
                              color: LinisColors.brand, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Text('Linis',
                            style: text.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Text('Trusted home cleaners in Davao City',
                        style: text.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1)),
                    const SizedBox(height: 16),
                    Text(
                      'See verified profiles, posted rates and real reviews '
                      'before anyone steps into your home.',
                      style: text.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    ..._points.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(p.$1, color: LinisColors.mint, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(p.$2,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 15)),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 32),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: LinisColors.brandDark,
                      ),
                      onPressed: () => _push(context,
                          const RegisterScreen(role: UserRole.customer)),
                      child: const Text('Book a cleaner'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: () => _push(context,
                          const RegisterScreen(role: UserRole.provider)),
                      child: const Text('Offer cleaning services'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => _push(context, const LoginScreen()),
                      child: const Text('I already have an account · Log in'),
                    ),
                    if (isDemo) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Demo mode: sample data, resets when the app restarts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _points = [
    (Icons.verified_user_rounded, 'IDs and business permits checked by hand'),
    (Icons.request_quote_rounded, 'Price estimate before you confirm'),
    (Icons.star_rounded, 'Ratings from real past customers'),
    (Icons.account_balance_wallet_rounded,
        'Pay by GCash (held until the job is done) or cash'),
  ];

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
