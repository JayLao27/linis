/// Build-time configuration, supplied with `--dart-define`.
///
///   flutter run                                   -> live Firebase
///   flutter run --dart-define=CLOUDINARY_CLOUD_NAME=xxx \
///     --dart-define=CLOUDINARY_UPLOAD_PRESET=yyy  -> live Firebase + Cloudinary
///   flutter run --dart-define=LINIS_BACKEND=demo  -> offline demo (in-memory)
///
/// Google sign-in on Android normally needs no extra flag. If it fails with
/// a client ID error, also pass `--dart-define=GOOGLE_SERVER_CLIENT_ID=zzz`.
class AppConfig {
  AppConfig._();

  static const String backend =
      String.fromEnvironment('LINIS_BACKEND', defaultValue: 'firebase');

  static bool get useFirebase => backend == 'firebase';

  /// Shows the one-tap sample account buttons on the login screen. The
  /// sample accounts are also saved in the Firebase project. Turn this off
  /// with `--dart-define=LINIS_SAMPLE_LOGINS=false` before a real launch.
  static const bool sampleLogins =
      bool.fromEnvironment('LINIS_SAMPLE_LOGINS', defaultValue: true);

  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  static bool get cloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static const String psgcBaseUrl = 'https://psgc.gitlab.io/api';
}
