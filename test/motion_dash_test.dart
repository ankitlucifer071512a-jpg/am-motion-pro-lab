import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/core/theme/app_theme.dart';
import 'package:my_first_app/models/motion_dash_engine.dart';
import 'package:my_first_app/screens/games/game_lab_screen.dart';
import 'package:my_first_app/screens/games/motion_dash_screen.dart';
import 'package:my_first_app/services/learning_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'shown lane color is the deterministic match and gates change cube color',
      () {
    final game = MotionDashEngine()..start();
    game.tick(3.1);
    expect(game.state, MotionDashState.running);
    expect(game.cubeColor, CubeColor.blue);
    expect(game.events.first.boxColors.first, game.cubeColor);

    game.moveLane(-1);
    game.tick(3.99);
    expect(game.passedObstacles, 0);
    game.tick(.02);
    expect(game.passedObstacles, 1);
    expect(game.score, 100);
    expect(game.combo, 1);

    game.tick(2.2);
    expect(game.cubeColor, isNot(CubeColor.blue));
    final nextObstacle = game.events[2];
    expect(nextObstacle.boxColors, contains(game.cubeColor));
    game.moveLane(nextObstacle.boxColors.indexOf(game.cubeColor) - game.lane);
    game.tick(nextObstacle.time - game.elapsed + .02);
    expect(game.passedObstacles, 2);
    expect(game.mistakes, 0);
  });

  test('wrong color causes a mistake while a matching lane passes', () {
    final game = MotionDashEngine()..start();
    game.tick(3.1);
    game.tick(4.01);
    expect(game.mistakes, 1);
    expect(game.feedback, 'WRONG COLOR');
    expect(game.combo, 0);
  });

  test(
      'finish requires a creative challenge and correct answer unlocks next round',
      () {
    final game = MotionDashEngine()..start();
    game.tick(3.1);
    while (game.state == MotionDashState.running) {
      final event = game.nextEvent!;
      if (event.type == RunnerEventType.matchingBoxes) {
        final correctLane = event.boxColors.indexOf(game.cubeColor);
        game.moveLane(correctLane - game.lane);
      } else if (event.type == RunnerEventType.barrier &&
          game.lane == event.blockedLane) {
        game.moveLane((game.lane + 1) % 3 - game.lane);
      }
      final seconds = (event.time - game.elapsed) / game.speed + .01;
      game.tick(seconds);
    }
    expect(game.state, MotionDashState.challenge);
    final before = game.score;
    final wrong = (game.challenge.answer + 1) % game.challenge.options.length;
    expect(game.submitChallenge(wrong), isFalse);
    expect(game.state, MotionDashState.challenge);
    expect(game.submitChallenge(game.challenge.answer), isTrue);
    expect(game.state, MotionDashState.roundComplete);
    expect(game.score, before + 250);
    expect(game.completedRounds, 1);
    expect(game.unlockedRound, 2);
    expect(MotionDashEngine.challengeForRound(2).category, 'TYPOGRAPHY');
  });

  test('later rounds increase speed and introduce moving blockers and bonuses',
      () {
    final roundFour = MotionDashEngine()..start(selectedRound: 4);
    final roundFive = MotionDashEngine()..start(selectedRound: 5);
    expect(roundFour.speed, greaterThan(1));
    expect(
        roundFour.events
            .any((e) => e.type == RunnerEventType.barrier && e.moving),
        isTrue);
    expect(roundFive.events.any((e) => e.bonus), isTrue);
    expect(roundFive.events.any((e) => e.type == RunnerEventType.gap), isTrue);
  });

  test('round five gap only passes through its clearly marked safe lane', () {
    final game = MotionDashEngine()..start(selectedRound: 5);
    game.tick(3.1);
    while (game.nextEvent?.type != RunnerEventType.gap) {
      final event = game.nextEvent!;
      if (event.type == RunnerEventType.matchingBoxes) {
        game.moveLane(event.boxColors.indexOf(game.cubeColor) - game.lane);
      } else if (event.type == RunnerEventType.barrier &&
          event.blockedLane == game.lane) {
        game.moveLane((game.lane + 1) % 3 - game.lane);
      }
      game.tick((event.time - game.elapsed) / game.speed + .01);
    }
    final gap = game.nextEvent!;
    game.moveLane(gap.safeLane! - game.lane);
    game.tick((gap.time - game.elapsed) / game.speed + .01);
    expect(game.feedback, startsWith('SAFE PATH'));
    expect(game.mistakes, 0);
  });

  test('pause and resume retain the active round and lane', () {
    final game = MotionDashEngine()..start();
    game.tick(3.1);
    game.moveLane(-1);
    game.pause();
    expect(game.state, MotionDashState.paused);
    expect(game.lane, 0);
    game.resume();
    expect(game.state, MotionDashState.running);
    expect(game.round, 1);
    expect(game.lane, 0);
  });

  test('round completion and best score persist in the existing progress store',
      () async {
    final store = LearningProgressStore.instance;
    await store.recordMotionDashRoundCompleted(420, 1);
    await store.recordMotionDashRoundCompleted(300, 1);
    expect(await store.motionDashBest, 420);
    expect(await store.motionDashUnlockedRound, 2);
    expect(await store.motionDashCompletedRounds, 1);
  });

  testWidgets('Color Cube Runner starts and can pause and resume',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const MotionDashScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Start Round 1'), findsOneWidget);
    expect(find.byTooltip('LEFT LANE'), findsNothing);

    await tester.tap(find.text('Start Round 1'));
    for (var i = 0; i < 65; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byTooltip('LEFT LANE'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    expect(find.text('Run paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.byTooltip('Pause game'), findsOneWidget);
  });

  testWidgets('Color Cube Runner opens from the existing Game Lab card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: GameLabScreen()),
    ));
    final card = find.text('Motion Dash · Color Cube Runner');
    await tester.scrollUntilVisible(card, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Color Cube Runner'), findsOneWidget);
    expect(find.text('Start Round 1'), findsOneWidget);
  });
}
