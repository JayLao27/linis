import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/backend.dart';
import 'data/models/enums.dart';
import 'state/session_controller.dart';
import 'ui/screens/admin/admin_shell.dart';
import 'ui/screens/auth/welcome_screen.dart';
import 'ui/screens/customer/customer_shell.dart';
import 'ui/screens/provider/provider_onboarding_screen.dart';
import 'ui/screens/provider/provider_pending_screen.dart';
import 'ui/screens/provider/provider_shell.dart';
import 'ui/theme.dart';

class LinisApp extends StatelessWidget {
  const LinisApp({super.key, required this.backend});
  final Backend backend;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider<Backend>.value(value: backend),
          ChangeNotifierProvider(create: (_) => SessionController(backend)),
        ],
        child: MaterialApp(
          title: 'Linis',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          home: const RootGate(),
        ),
      );
}

/// Picks the home screen from who is signed in and, for providers, where they
/// are in verification.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.status == SessionStatus.signedOut) return const WelcomeScreen();
    if (!session.isReady) return const _Splash();

    return switch (session.user!.role) {
      UserRole.customer => const CustomerShell(),
      UserRole.admin => const AdminShell(),
      UserRole.provider => switch (session.provider!.verificationStatus) {
          VerificationStatus.approved => const ProviderShell(),
          VerificationStatus.pending => const ProviderPendingScreen(),
          VerificationStatus.incomplete ||
          VerificationStatus.rejected =>
            const ProviderOnboardingScreen(),
        },
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 56),
                  const SizedBox(height: 16),
                  const Text('Linis could not start',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
}
