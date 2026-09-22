import 'package:flutter/material.dart';

import 'app.dart';
import 'data/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final backend = await Backend.create();
    runApp(LinisApp(backend: backend));
  } catch (e) {
    runApp(StartupErrorApp(error: e));
  }
}
