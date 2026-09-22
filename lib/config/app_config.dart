/// Build-time configuration, supplied with `--dart-define`.
///
///   flutter run                                   -> demo backend (in-memory, seeded)
///   flutter run --dart-define=LINIS_BACKEND=firebase \
///     --dart-define=CLOUDINARY_CLOUD_NAME=xxx \
///     --dart-define=CLOUDINARY_UPLOAD_PRESET=yyy  -> live Firebase + Cloudinary
class AppConfig {
  AppConfig._();

  static const String backend =
      String.fromEnvironment('LINIS_BACKEND', defaultValue: 'demo');

  static bool get useFirebase => backend == 'firebase';

  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  static bool get cloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static const String psgcBaseUrl = 'https://psgc.gitlab.io/api';
}
