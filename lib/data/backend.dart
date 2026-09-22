import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/app_config.dart';
import '../firebase_options.dart';
import 'demo_seed.dart';
import 'models/enums.dart';
import 'repositories/auth_repository.dart';
import 'repositories/booking_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/ledger_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/provider_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/user_repository.dart';
import 'services/image_upload_service.dart';
import 'services/payment_gateway.dart';
import 'services/pricing_service.dart';
import 'services/psgc_service.dart';

/// Everything the UI talks to. Built once at startup, either against live
/// Firebase or against an in-memory Firestore seeded with Davao sample data.
class Backend {
  Backend._({
    required this.db,
    required this.auth,
    required this.uploads,
    required this.isDemo,
    PaymentGateway? payments,
    PsgcService? psgc,
  })  : payments = payments ?? SimulatedGCashGateway(),
        psgc = psgc ?? PsgcService() {
    notifications = NotificationRepository(db);
    users = UserRepository(db);
    providers = ProviderRepository(db, notifications);
    bookings = BookingRepository(db, providers, notifications, pricing: pricing);
    reviews = ReviewRepository(db, notifications);
    ledger = LedgerRepository(db, notifications);
    chat = ChatRepository(db, notifications);
  }

  final FirebaseFirestore db;
  final AuthRepository auth;
  final ImageUploadService uploads;
  final PaymentGateway payments;
  final PsgcService psgc;
  final bool isDemo;
  final PricingService pricing = const PricingService();

  late final NotificationRepository notifications;
  late final UserRepository users;
  late final ProviderRepository providers;
  late final BookingRepository bookings;
  late final ReviewRepository reviews;
  late final LedgerRepository ledger;
  late final ChatRepository chat;

  static Future<Backend> create() {
    if (AppConfig.useFirebase) return firebase();
    // fake_cloud_firestore refuses to run without assertions (release builds).
    var assertionsOn = false;
    assert(assertionsOn = true);
    if (!assertionsOn) {
      throw StateError('The demo backend only runs in debug builds. '
          'Build with --dart-define=LINIS_BACKEND=firebase for release.');
    }
    return demo();
  }

  static Future<Backend> firebase() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    return Backend._(
      db: FirebaseFirestore.instance,
      auth: FirebaseAuthRepository(FirebaseAuth.instance),
      uploads: AppConfig.cloudinaryConfigured
          ? CloudinaryUploadService()
          : MemoryUploadService(),
      isDemo: false,
    );
  }

  /// In-memory backend. Pass `seed: false` for an empty database (tests).
  static Future<Backend> demo({
    bool seed = true,
    PaymentGateway? payments,
    PsgcService? psgc,
  }) async {
    final auth = DemoAuthRepository();
    final backend = Backend._(
      db: FakeFirebaseFirestore(),
      auth: auth,
      uploads: MemoryUploadService(),
      isDemo: true,
      payments: payments,
      psgc: psgc,
    );
    if (seed) await DemoSeed(backend.db, auth).run();
    return backend;
  }

  /// Creates the login, the `users` document and, for providers, a draft
  /// `providers` document that onboarding fills in.
  Future<String> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    ProviderTier? tier,
    String? businessName,
  }) async {
    assert(role != UserRole.provider || tier != null);
    final uid = await auth.register(email, password);
    await users.create(
        uid: uid, role: role, fullName: fullName, email: email, phone: phone);
    if (role == UserRole.provider) {
      await providers.createDraft(
        uid: uid,
        tier: tier!,
        displayName: tier == ProviderTier.company &&
                (businessName ?? '').trim().isNotEmpty
            ? businessName!.trim()
            : fullName.trim(),
        phone: phone,
        businessName: businessName?.trim(),
      );
    }
    return uid;
  }
}
