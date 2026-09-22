# Linis

A mobile marketplace for home cleaning services in Davao City. Customers pick a
service, home size, date and address, see an estimated price, and book either a
cleaning **company** or an **individual** cleaner. Linis keeps a commission on
every completed booking.

## Running it

### Demo mode (no setup)

```sh
flutter pub get
flutter run
```

Without any flags the app uses an **in-memory backend** seeded with sample
Davao data (Buhangin, Matina Crossing, Talomo…). Data resets on restart. Demo
mode only works in **debug** builds.

| Role | Email | Password |
|---|---|---|
| Customer | customer@linis.ph | linis123 |
| Individual cleaner | maria@linis.ph | linis123 |
| Cleaning company | sparkle@linis.ph | linis123 |
| Cleaner awaiting verification | rosa@linis.ph | linis123 |
| Admin | admin@linis.ph | linis123 |

The login screen has one-tap buttons for these. On web you can also open
`?as=customer`, `?as=cleaner`, `?as=company`, `?as=pending` or `?as=admin`.

### Live Firebase

1. Create a Firebase project. Enable **Authentication → Email/Password** and
   **Cloud Firestore**.
2. From this folder:
   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This overwrites `lib/firebase_options.dart`.
3. Deploy the rules and indexes:
   ```sh
   firebase deploy --only firestore
   ```
4. (Optional) Create a Cloudinary **unsigned upload preset** for photos, IDs and
   permits.
5. Run:
   ```sh
   flutter run --dart-define=LINIS_BACKEND=firebase \
     --dart-define=CLOUDINARY_CLOUD_NAME=<cloud> \
     --dart-define=CLOUDINARY_UPLOAD_PRESET=<preset>
   ```
6. Make an admin: register normally, then change that user's `role` to
   `admin` in the Firestore console.

## Tests

```sh
flutter test
```

`test/backend_test.dart` covers pricing, commission, the full booking lifecycle
(GCash and cash), the settlement cap, two-way ratings, declines and refunds.
`test/app_flow_test.dart` drives the UI for each role.

## How it's built

```
lib/
  config/        build-time flags (backend, Cloudinary)
  core/          business constants (commission, cap), formatting
  data/
    models/      Firestore documents: users, providers, bookings, reviews,
                 notifications, ledger
    repositories/ all reads and writes; money and assignment changes run in
                 Firestore transactions
    services/    pricing, PSGC address API, image uploads, GCash gateway
    backend.dart wires everything; demo_seed.dart is the sample data
  state/         SessionController (who's signed in), BookingDraft (booking
                 flow + live estimate), both via `provider`
  ui/            theme, shared widgets, screens per role
```

**Booking lifecycle:** `pending → accepted → inProgress → awaitingConfirmation
→ completed` (or `cancelled` before work starts). The first provider to accept
gets the job, and the price and commission are fixed at that moment.

**Matching:** providers store their service areas as PSGC barangay codes.
Requests match on `barangayCode`, not distance. A provider can pick up to 30
areas, which is Firestore's `whereIn` limit.

**Money:**
- **GCash:** the customer pays after acceptance and Linis holds the money. When
  the customer confirms the job, the provider's share is released and the
  commission (10% individual, 15% company) is kept.
- **Cash:** the commission is added to the provider's unsettled balance. At
  ₱1,500 owed, new bookings pause until the provider settles via GCash or an
  admin marks the balance as settled.

**Recurring plans:** a customer can book a clean every week (10% off) or every
2 weeks (5% off) for 4, 8 or 12 visits. The first visit goes out like any
request. The provider who accepts it commits to the whole plan at that
per-visit price (stored in `plans/{id}`). When a visit is confirmed done or
skipped, the next one is created automatically as an accepted booking with the
same provider, slot and price, one interval later. The customer pays each visit
separately. Either side can skip a single visit or end the plan. Ending a plan
cancels the open visit and refunds it if it was paid by GCash. In the demo,
Ben's job with Maria is visit 1 of a weekly plan.

**Chat:** once a cleaner accepts, the customer and cleaner can message each
other on the booking (`bookings/{id}/messages`). Quick replies cover common
messages like "I'm on my way" and "The gate is open". The booking document keeps
the last message and each side's read time, so booking cards show unread
previews without loading the conversation. A burst of messages sends one
notification until the recipient reads them. Chat becomes read-only when the
booking is completed or cancelled. In the demo, Maria has an unread message
from Ben.

## Known limitations

- **GCash is simulated** (`SimulatedGCashGateway`). A real integration needs a
  payment provider such as PayMongo, a merchant account, and a server to
  receive payment webhooks.
- **Notifications are in-app** (a live Firestore feed with unread badges). Push
  notifications need Firebase Cloud Messaging plus a Cloud Function to send
  them.
- **Money is computed on the client**, inside transactions. The security rules
  limit who can change which fields. For production, move
  `confirmCompletion`, `settle` and review averaging into Cloud Functions.
- **Documents are public URLs** with Cloudinary unsigned uploads. Use signed or
  authenticated delivery for IDs and permits.
