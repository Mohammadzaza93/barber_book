import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:barber_app/widgets/data_state_view.dart';
import 'package:barber_app/widgets/empty_state.dart';

/// PHASE 3.2 coverage for the shared provider-state renderer.
///
/// The widget is intentionally dumb: it maps whatever the provider reported to
/// a user-facing state. These tests lock the precedence (denied > error >
/// loading > content) and that retry is only wired from the error state.
Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows content once loaded with no denial or error',
      (tester) async {
    await tester.pumpWidget(_host(const DataStateView(
      loading: false,
      permissionDenied: false,
      error: null,
      child: Text('CONTENT'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('CONTENT'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(EmptyState), findsNothing);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    await tester.pumpWidget(_host(const DataStateView(
      loading: true,
      permissionDenied: false,
      error: null,
      child: Text('CONTENT'),
    )));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('CONTENT'), findsNothing);
  });

  testWidgets('denial wins over loading/error and hides retry',
      (tester) async {
    await tester.pumpWidget(_host(DataStateView(
      loading: true,
      permissionDenied: true,
      error: 'boom',
      onRetry: () {},
      child: const Text('CONTENT'),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Access restricted'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('CONTENT'), findsNothing);
    // Retry belongs to transient errors, not capability boundaries.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('error state offers a working retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(_host(DataStateView(
      loading: false,
      permissionDenied: false,
      error: 'boom',
      onRetry: () => retries++,
      child: const Text('CONTENT'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('CONTENT'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('error state hides retry when no callback is supplied',
      (tester) async {
    await tester.pumpWidget(_host(const DataStateView(
      loading: false,
      permissionDenied: false,
      error: 'boom',
      child: Text('CONTENT'),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
