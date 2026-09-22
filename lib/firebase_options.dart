// PLACEHOLDER. Replace this file by running, from the project root:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// flutterfire generates a `DefaultFirebaseOptions` class with the same name,
// so nothing else in the app needs to change. Until then the app runs on the
// in-memory demo backend (see lib/config/app_config.dart).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet. Run `flutterfire configure`, '
      'or start the app without --dart-define=LINIS_BACKEND=firebase '
      'to use the demo backend.',
    );
  }
}
