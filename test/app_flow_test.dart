import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linis/app.dart';
import 'package:linis/data/backend.dart';
import 'package:linis/data/demo_seed.dart';

Future<Backend> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final backend = (await tester.runAsync(() => Backend.demo()))!;
  await tester.pumpWidget(LinisApp(backend: backend));
  await tester.pumpAndSettle();
  return backend;
}

Future<void> _login(WidgetTester tester, String email) async {
  await tester.ensureVisible(find.textContaining('Log in'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Log in'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'), DemoSeed.password);
  await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('customer logs in, sees home, and walks the booking flow',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text('Trusted home cleaners in Davao City'), findsOneWidget);

    await _login(tester, DemoSeed.customerEmail);
    expect(find.text('Hi Carla!'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('SparkleCrew Cleaning Services'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book a cleaning'));
    await tester.pumpAndSettle();
    expect(find.text('What needs cleaning?'), findsOneWidget);

    // Estimate reacts to home size.
    final before = tester.widget<Text>(find.textContaining('₱').last).data;
    await tester.ensureVisible(find.text('4+ bedrooms / large house'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4+ bedrooms / large house'));
    await tester.pumpAndSettle();
    final after = tester.widget<Text>(find.textContaining('₱').last).data;
    expect(after, isNot(before));

    // Schedule step blocks "Next" until a date and time are picked.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a date'), findsOneWidget);
    expect(find.text('Pick a start time'), findsOneWidget);

    // Choosing a weekly plan shows visit counts and a per-visit price.
    final weekly = find.text('Every week · save 10%');
    await tester.ensureVisible(weekly);
    await tester.pumpAndSettle();
    await tester.tap(weekly);
    await tester.pumpAndSettle();
    expect(find.text('8 visits'), findsOneWidget);
    expect(find.text('Estimated price per visit'), findsOneWidget);
  });

  testWidgets('a wrong password shows an error and stays on login',
      (tester) async {
    final backend = await _pumpApp(tester);
    await tester.ensureVisible(find.textContaining('Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Log in'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), DemoSeed.customerEmail);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'not-the-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(backend.auth.currentUid, isNull);
  });

  testWidgets('new customer registers with email and lands on home',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Book a cleaner'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Nina Cruz');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile number'), '09171112222');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'nina@test.ph');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret1');
    // Close the keyboard so the form can scroll down to the checkbox.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Hi Nina!'), findsOneWidget);
  });

  testWidgets('new customer signs up with Google', (tester) async {
    final backend = await _pumpApp(tester);
    await tester.tap(find.text('Book a cleaner'));
    await tester.pumpAndSettle();

    final google = find.text('Continue with Google');
    await tester.ensureVisible(google);
    await tester.pumpAndSettle();

    // The terms must be accepted first.
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(find.text('Please agree to the terms to continue.'), findsOneWidget);
    expect(backend.auth.currentUid, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(find.text('Hi Juan!'), findsOneWidget);
  });

  testWidgets('customer views, edits and deletes a saved place',
      (tester) async {
    final backend = await _pumpApp(tester);
    await _login(tester, DemoSeed.customerEmail);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved places'));
    await tester.pumpAndSettle();
    expect(find.text('Rental condo'), findsOneWidget);
    expect(find.textContaining('Emily Homes'), findsOneWidget);

    // Edit: rename the condo.
    await tester.tap(find.text('Rental condo'));
    await tester.pumpAndSettle();
    expect(find.text('Edit place'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Beach condo');
    // Close the keyboard so the form can scroll down to the save button.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Beach condo'), findsOneWidget);
    expect(find.text('Rental condo'), findsNothing);

    // Delete it from the card menu.
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Beach condo'), findsNothing);

    final left = await tester
        .runAsync(() => backend.places.watchFor('cust-carla').first);
    expect(left!.single.label, 'Home');
  });

  testWidgets('provider sees the open Buhangin request and can open it',
      (tester) async {
    await _pumpApp(tester);
    await _login(tester, DemoSeed.individualEmail);
    expect(find.text('Job requests'), findsOneWidget);
    expect(find.text('Carla Mendoza'), findsOneWidget);

    await tester.tap(find.text('Earnings'));
    await tester.pumpAndSettle();
    expect(find.text('Commission owed'), findsOneWidget);

    await tester.tap(find.text('My jobs'));
    await tester.pumpAndSettle();
    expect(find.text('Ben Tan'), findsOneWidget);
    expect(find.text('Every week · visit 1 of 8'), findsOneWidget);

    await tester.tap(find.text('Ben Tan'));
    await tester.pumpAndSettle();
    expect(find.text('Recurring plan'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('End plan'), findsOneWidget);
  });

  testWidgets('cleaner reads an unread message and replies', (tester) async {
    final backend = await _pumpApp(tester);
    await _login(tester, DemoSeed.individualEmail);
    await tester.tap(find.text('My jobs'));
    await tester.pumpAndSettle();

    // Unread preview on the card.
    expect(find.textContaining('keep the screen door closed'), findsOneWidget);

    await tester.tap(find.text('Ben Tan'));
    await tester.pumpAndSettle();
    expect(find.text('New message'), findsOneWidget);

    await tester.tap(find.text('New message'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mention Blk 3 Lot 12'), findsOneWidget);

    await tester.tap(find.text("I'm on my way"));
    await tester.pumpAndSettle();
    expect(find.text("I'm on my way"), findsNWidgets(2)); // chip + bubble

    final b = await tester.runAsync(() => backend.bookings.watch('seed-b3').first);
    expect(b!.lastMessageText, "I'm on my way");
    expect(b.hasUnreadFor('prov-maria'), isFalse);
    expect(b.hasUnreadFor('cust-ben'), isTrue);
  });

  testWidgets('admin approves a pending cleaner', (tester) async {
    final backend = await _pumpApp(tester);
    await _login(tester, DemoSeed.adminEmail);
    expect(find.text('Verification queue'), findsOneWidget);
    expect(find.text('Rosa Villanueva'), findsOneWidget);

    await tester.tap(find.text('Rosa Villanueva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    final rosa = await tester.runAsync(() => backend.providers.get('prov-rosa'));
    expect(rosa!.isApproved, isTrue);
    expect(find.text('Rosa Villanueva'), findsNothing);
  });

  testWidgets('pending provider lands on the review screen', (tester) async {
    await _pumpApp(tester);
    await _login(tester, DemoSeed.pendingEmail);
    expect(find.text('Your profile is under review'), findsOneWidget);
  });
}
