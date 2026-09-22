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
