import 'package:flutter/material.dart';

import 'app.dart';
import 'data/backend.dart';
import 'data/demo_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final backend = await Backend.create();
    if (backend.isDemo) await _demoAutoLogin(backend);
    runApp(LinisApp(backend: backend));
  } catch (e) {
    runApp(StartupErrorApp(error: e));
  }
}

/// Demo only: on web, `?as=customer|cleaner|company|pending|admin` opens the
/// app already signed in to that sample account.
Future<void> _demoAutoLogin(Backend backend) async {
  final email = switch (Uri.base.queryParameters['as']) {
    'customer' => DemoSeed.customerEmail,
    'cleaner' => DemoSeed.individualEmail,
    'company' => DemoSeed.companyEmail,
    'pending' => DemoSeed.pendingEmail,
    'admin' => DemoSeed.adminEmail,
    _ => null,
  };
  if (email != null) await backend.auth.signIn(email, DemoSeed.password);
}
