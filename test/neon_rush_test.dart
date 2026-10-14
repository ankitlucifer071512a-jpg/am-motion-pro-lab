import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/core/theme/app_theme.dart';
import 'package:my_first_app/screens/games/neon_rush_screen.dart';
import 'package:my_first_app/services/learning_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Neon Rush starts, accepts lane swipes and pauses/resumes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const NeonRushScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Start running'), findsOneWidget);

    await tester.tap(find.text('Start running'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('JUMP'), findsOneWidget);
    expect(find.text('SLIDE'), findsOneWidget);

    await tester.tap(find.text('JUMP'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('SLIDE'));
    await tester.pump(const Duration(milliseconds: 60));
    final playfield = find.byType(GestureDetector).first;
    await tester.drag(playfield, const Offset(-130, 0));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('LEFT'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    await tester.tap(find.text('Restart run'));
    await tester.pump();
    expect(find.text('JUMP'), findsOneWidget);
  });

  test('Neon Rush best score and recent run history persist locally', () async {
    final store = LearningProgressStore.instance;
    await store.recordNeonRushRun(240);
    await store.recordNeonRushRun(120);
    expect(await store.neonRushBest, 240);
    expect(await store.neonRushHistory, [120, 240]);
    expect(await store.unlockNeonRushAchievement('orb_collector'), isTrue);
    expect(await store.unlockNeonRushAchievement('orb_collector'), isFalse);
  });
}
