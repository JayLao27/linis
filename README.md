# Linis

A mobile marketplace for home cleaning services in Davao City. Customers pick a
service, home size, date and address, see an estimated price, and book either a
cleaning **company** or an **individual** cleaner. Linis keeps a commission on
every completed booking.

## Running it

```sh
flutter pub get
flutter run
```

The app runs on the live Firebase project **`linis-davao`** (Firestore in
Singapore). Email/password and Google sign-in are both turned on there.

### Sample accounts

These accounts and their sample Davao data (Buhangin, Matina Crossing,
Talomo…) are saved in the Firebase project, so they work on any device.

| Role | Email | Password |
|---|---|---|
| Customer | customer@linis.ph | linis123 |
| Individual cleaner | maria@linis.ph | linis123 |
| Cleaning company | sparkle@linis.ph | linis123 |
| Cleaner awaiting verification | rosa@linis.ph | linis123 |
| Admin | admin@linis.ph | linis123 |

The login screen has one-tap buttons for these. Hide the buttons with
`--dart-define=LINIS_SAMPLE_LOGINS=false`. Before a real launch, also delete
these accounts in the Firebase console, because the passwords are public.

### Google sign-in

- **Register:** choose "Book a cleaner" or "Offer cleaning services", tick the
  terms, then tap **Continue with Google**. The name, email and photo come from
  Google.
- **Log in:** tap **Continue with Google** on the login screen. A Google
  account that has not registered is refused, and its login is removed again.
- **Android:** Google only accepts builds signed with a key that is listed in
  **Firebase console → Project settings → Your apps → Android app**. The debug
  key of the first development PC is already there. On another PC, or for a
  release build, get the key with `cd android && ./gradlew signingReport`, add
  its `SHA1`, then run `flutterfire configure` again.

### After cloning

`android/app/google-services.json` is not in git. Create it with:

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=linis-davao
```

### Photos

Uploaded photos (profile photos, IDs, permits, saved places) are saved in the
Firebase database under `images/{id}`, so they show on every device with no
extra setup. Photos are shrunk before upload and must be under about 900 KB.

To use Cloudinary instead, create an **unsigned upload preset** and run:

```sh
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=<cloud> \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=<preset>
```

### Offline demo mode

```sh
flutter run --dart-define=LINIS_BACKEND=demo
```

This uses an in-memory copy of the same sample data and needs no internet. Data
resets on restart, Google sign-in is simulated (it always signs in as "Juan
Dela Cruz"), and it only works in **debug** builds. On web you can also open
`?as=customer`, `?as=cleaner`, `?as=company`, `?as=pending` or `?as=admin`.

### Changing the rules or sign-in methods

```sh
firebase deploy --only firestore,auth
```

To make another admin, register normally, then change that user's `role` to
`admin` in the Firestore console.

## Tests

```sh
flutter test
```

`test/backend_test.dart` covers pricing, commission, the full booking lifecycle
(GCash and cash), the settlement cap, two-way ratings, declines and refunds,
saved places (create, read, update, delete) and Google sign-in.
`test/app_flow_test.dart` drives the UI for each role. The tests use the
in-memory demo backend, so they never touch the Firebase project.

## How it's built

```
lib/
  config/        build-time flags (backend, Cloudinary)
  core/          business constants (commission, cap), formatting
  data/
    models/      Firestore documents: users, providers, bookings, reviews,
                 notifications, ledger, places
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

**Saved places (CRUD):** a customer keeps a list of the homes they get cleaned
under **Account → Saved places** (`places/{id}` in Firestore). Each place has a
name, home size, address, notes and a photo.

| Action | Where in the app | Code |
|---|---|---|
| Create | **Add place** button, then the form | `PlaceRepository.create` |
| Read | The list of cards, which updates live | `PlaceRepository.watchFor` |
| Update | Tap a card, or **⋮ → Edit** | `PlaceRepository.update` |
| Delete | **⋮ → Delete**, then confirm | `PlaceRepository.delete` |

The list (`SavedPlacesScreen`) and its cards are `StatelessWidget`s because
they only show data. The form (`PlaceFormScreen`) is a `StatefulWidget` because
it changes as the user types, picks a size and uploads a photo.

**Google sign-in:** the login and register screens both have a **Continue with
Google** button. On the register screen it creates the account, using the name,
email and photo from Google. On the login screen it only lets in Google
accounts that already have a Linis account, because a new account must first
choose to be a customer or a cleaner. Accounts made with Google start without a
mobile number unless one was typed in the form. Customers can add it later
under **Account → Edit name & phone**.

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
- **Uploaded IDs and permits can be viewed by any signed-in user** who has the
  link, and Cloudinary uploads are public URLs. For production, limit them to
  the owner and admins.
