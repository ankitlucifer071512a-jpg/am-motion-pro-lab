import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:my_first_app/widgets/brand_intro.dart';

void main() {
  testWidgets('shows the branded intro once before the existing home', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrandIntro(child: Scaffold(body: Text('Home screen'))),
      ),
    );

    expect(find.byKey(const ValueKey('am-motion-intro')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('LEARN . CREATE . EARN'), findsOneWidget);
    expect(find.text('Home screen'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('am-motion-intro')), findsNothing);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('tap skips the intro while initialization completes', (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntro(
          initialization: initialization.future,
          child: const Scaffold(body: Text('Home screen')),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('am-motion-intro')));
    await tester.pump();
    expect(find.byKey(const ValueKey('am-motion-intro')), findsOneWidget);
    initialization.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('am-motion-intro')), findsNothing);
    expect(find.text('Home screen'), findsOneWidget);
  });

  testWidgets('reduced motion shows a static logo and tagline', (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: BrandIntro(
            initialization: initialization.future,
            child: const Scaffold(body: Text('Home screen')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('LEARN . CREATE . EARN'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Home screen'), findsNothing);
    initialization.complete();
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
  });
}
