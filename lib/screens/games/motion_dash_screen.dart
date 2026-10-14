import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/motion_dash_engine.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/glass_card.dart';

class MotionDashScreen extends StatefulWidget {
  const MotionDashScreen({super.key});
  @override
  State<MotionDashScreen> createState() => _MotionDashScreenState();
}

class _MotionDashScreenState extends State<MotionDashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _engine = MotionDashEngine();
  final _store = LearningProgressStore.instance;
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration? _lastTick;
  bool _loading = true;
  bool _reducedEffects = false;
  bool _sound = false;
  int _best = 0;
  int _selectedAnswer = -1;
  String? _challengeMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final values = await Future.wait<Object>([
      _store.motionDashBest,
      _store.motionDashUnlockedRound,
      _store.motionDashCompletedRounds,
    ]);
    if (!mounted) return;
    _engine.restoreProgress(
      unlocked: values[1] as int,
      completed: values[2] as int,
    );
    setState(() {
      _best = values[0] as int;
      _loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _startRound() {
    _selectedAnswer = -1;
    _challengeMessage = null;
    _engine.start();
    _lastTick = null;
    setState(() {});
    _ticker.start();
  }

  void _tick(Duration timestamp) {
    if (_engine.state != MotionDashState.countdown &&
        _engine.state != MotionDashState.running) {
      return;
    }
    final oldState = _engine.state;
    final oldIndex = _engine.nextEventIndex;
    final dt = _lastTick == null
        ? 1 / 60
        : ((timestamp - _lastTick!).inMicroseconds / 1000000).clamp(0.0, .05);
    _lastTick = timestamp;
    _engine.tick(dt);
    _frame.value++;
    if (_engine.nextEventIndex != oldIndex) {
      if (_sound) {
        unawaited(SystemSound.play(SystemSoundType.click));
      }
      unawaited(HapticFeedback.lightImpact());
      _best = math.max(_best, _engine.score);
      unawaited(_store.recordMotionDashBestScore(_engine.score));
    }
    if (oldState != _engine.state) {
      if (_engine.state == MotionDashState.challenge ||
          _engine.state == MotionDashState.gameOver) {
        _ticker.stop();
        _saveBestScore();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveBestScore() async {
    await _store.recordMotionDashBestScore(_engine.score);
    if (mounted) setState(() => _best = math.max(_best, _engine.score));
  }

  void _pause() {
    if (_engine.state != MotionDashState.running &&
        _engine.state != MotionDashState.countdown) {
      return;
    }
    _engine.pause();
    _ticker.stop();
    _lastTick = null;
    setState(() {});
  }

  void _resume() {
    if (_engine.state != MotionDashState.paused) return;
    _engine.resume();
    _lastTick = null;
    setState(() {});
    _ticker.start();
  }

  void _moveLane(int direction) {
    final lane = _engine.lane;
    _engine.moveLane(direction);
    if (_engine.lane != lane) {
      HapticFeedback.selectionClick();
      _frame.value++;
    }
  }

  void _swipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() >= 90) _moveLane(velocity < 0 ? -1 : 1);
  }

  Future<void> _submitChallenge() async {
    if (_selectedAnswer < 0) return;
    final correct = _engine.submitChallenge(_selectedAnswer);
    if (!correct) {
      setState(() => _challengeMessage = _engine.feedback);
      return;
    }
    setState(() => _challengeMessage = null);
    await _store.recordMotionDashRoundCompleted(_engine.score, _engine.round);
    await _store.completeChallenge('motion-dash-round-${_engine.round}');
    if (!mounted) return;
    setState(() => _best = math.max(_best, _engine.score));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _moveLane(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _moveLane(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _pause();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Color Cube Runner'),
            actions: [
              IconButton(
                tooltip: _sound ? 'Turn sound cues off' : 'Turn sound cues on',
                onPressed: () => setState(() => _sound = !_sound),
                icon: Icon(_sound
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded),
              ),
              IconButton(
                tooltip: 'Toggle reduced effects',
                onPressed: () =>
                    setState(() => _reducedEffects = !_reducedEffects),
                icon: Icon(_reducedEffects
                    ? Icons.motion_photos_off_outlined
                    : Icons.auto_awesome_outlined),
              ),
              if (_engine.state == MotionDashState.running ||
                  _engine.state == MotionDashState.countdown)
                IconButton(
                  tooltip: 'Pause game',
                  onPressed: _pause,
                  icon: const Icon(Icons.pause_rounded),
                ),
              if (_engine.state == MotionDashState.paused)
                IconButton(
                  tooltip: 'Resume game',
                  onPressed: _resume,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _frame,
                        builder: (context, _, __) => _hud(),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        final size =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        return Stack(fit: StackFit.expand, children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: _swipe,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _RunnerPainter(
                                  engine: _engine,
                                  repaint: _frame,
                                  reducedEffects: _reducedEffects,
                                ),
                                size: size,
                              ),
                            ),
                          ),
                          if (_engine.state == MotionDashState.ready)
                            _ReadyPanel(
                              round: _engine.unlockedRound,
                              completed: _engine.completedRounds,
                              best: _best,
                              onStart: _startRound,
                            ),
                          if (_engine.state == MotionDashState.countdown)
                            _CountdownPanel(engine: _engine, frame: _frame),
                          if (_engine.state == MotionDashState.paused)
                            _SimpleOverlay(
                              icon: Icons.pause_circle_outline_rounded,
                              title: 'Run paused',
                              message:
                                  'Round ${_engine.round} is saved in your progress.',
                              primary: 'Resume',
                              onPrimary: _resume,
                              secondary: 'Restart round',
                              onSecondary: _startRound,
                            ),
                          if (_engine.state == MotionDashState.challenge)
                            _ChallengePanel(
                              challenge: _engine.challenge,
                              round: _engine.round,
                              score: _engine.score,
                              selected: _selectedAnswer,
                              message: _challengeMessage,
                              onSelect: (index) => setState(() {
                                _selectedAnswer = index;
                                _challengeMessage = null;
                              }),
                              onSubmit: _submitChallenge,
                            ),
                          if (_engine.state == MotionDashState.roundComplete)
                            _SimpleOverlay(
                              icon: Icons.emoji_events_rounded,
                              title: 'Round ${_engine.round} complete!',
                              message:
                                  'Design challenge passed · +250 score\n${_engine.score} total points\nNext: Round ${_engine.unlockedRound}',
                              primary: 'Start Round ${_engine.unlockedRound}',
                              onPrimary: () {
                                _engine.startNextRound();
                                _selectedAnswer = -1;
                                _lastTick = null;
                                _frame.value++;
                                setState(() {});
                                _ticker.start();
                              },
                              secondary: 'Stay in Game Lab',
                              onSecondary: () => Navigator.of(context).pop(),
                            ),
                          if (_engine.state == MotionDashState.gameOver)
                            _SimpleOverlay(
                              icon: Icons.restart_alt_rounded,
                              title: 'Run over',
                              message:
                                  'Round ${_engine.round} · ${_engine.mistakes} mistakes\nScore ${_engine.score} · Best ${math.max(_best, _engine.score)}\nYour completed rounds remain saved.',
                              primary: 'Retry Round ${_engine.round}',
                              onPrimary: _startRound,
                              secondary: 'Return to Game Lab',
                              onSecondary: () => Navigator.of(context).pop(),
                            ),
                        ]);
                      }),
                    ),
                    if (_engine.state == MotionDashState.running ||
                        _engine.state == MotionDashState.countdown ||
                        _engine.state == MotionDashState.paused)
                      _laneControls(),
                  ]),
          ),
        ),
      );

  Widget _hud() => Column(children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(children: [
            _stat('ROUND', '${_engine.round}'),
            _stat('SCORE', '${_engine.score}'),
            _stat('BEST', '$_best'),
            _stat('COMBO', '×${_engine.combo}'),
            _stat('MISSES', '${_engine.mistakes}/3'),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: _engine.cubeColor.color,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                    color: _engine.cubeColor.color.withAlpha(130),
                    blurRadius: 13)
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('CUBE · ${_engine.cubeColor.label.toUpperCase()}',
              style: AppText.label.copyWith(color: _engine.cubeColor.color)),
          const Spacer(),
          Text(_eventHint(_engine.nextEvent, _engine.cubeColor),
              style: AppText.caption.copyWith(color: AppColors.ink)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: _engine.state == MotionDashState.running
                ? _engine.roundProgress
                : 0,
            minHeight: 4,
            backgroundColor: AppColors.glassFillStrong,
            valueColor: const AlwaysStoppedAnimation(AppColors.violet),
          ),
        ),
      ]);

  Widget _stat(String title, String value) => Expanded(
        child: Column(children: [
          Text(title, style: AppText.caption.copyWith(fontSize: 8)),
          Text(value,
              style:
                  AppText.h3.copyWith(fontSize: 13, color: AppColors.offWhite)),
        ]),
      );

  Widget _laneControls() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 11),
        child: Row(children: [
          _laneButton(
              Icons.chevron_left_rounded, 'LEFT LANE', () => _moveLane(-1)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(children: [
              Text('SWIPE OR CHANGE LANES',
                  style: AppText.label.copyWith(fontSize: 8)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: i == _engine.lane ? 17 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _engine.lane
                          ? _engine.cubeColor.color
                          : AppColors.inkFaint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 9),
          _laneButton(
              Icons.chevron_right_rounded, 'RIGHT LANE', () => _moveLane(1)),
        ]),
      );

  Widget _laneButton(IconData icon, String tooltip, VoidCallback action) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: action,
          borderRadius: BorderRadius.circular(12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 15),
            child: Icon(icon, color: AppColors.sky, size: 25),
          ),
        ),
      );
}

class _ReadyPanel extends StatelessWidget {
  const _ReadyPanel(
      {required this.round,
      required this.completed,
      required this.best,
      required this.onStart});
  final int round, completed, best;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => _CenterCard(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.view_in_ar_rounded, color: AppColors.sky, size: 42),
          const SizedBox(height: 7),
          Text('COLOR CUBE RUNNER',
              style: AppText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text(
              '3D-style perspective runner · Match your cube color to a track box. Rings shift your color. Dodge barriers by switching lanes.',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('ROUND $round · $completed COMPLETE · BEST $best',
              style: AppText.label, textAlign: TextAlign.center),
          const SizedBox(height: 11),
          FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Start Round $round')),
        ]),
      );
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.engine, required this.frame});
  final MotionDashEngine engine;
  final ValueListenable<int> frame;
  @override
  Widget build(BuildContext context) => Center(
        child: ValueListenableBuilder<int>(
          valueListenable: frame,
          builder: (context, _, __) => Text(
            '${engine.countdown.ceil().clamp(1, 3)}',
            style: AppText.h1.copyWith(
                fontSize: 78,
                color: AppColors.sky,
                shadows: const [Shadow(color: AppColors.blue, blurRadius: 28)]),
          ),
        ),
      );
}

class _ChallengePanel extends StatelessWidget {
  const _ChallengePanel(
      {required this.challenge,
      required this.round,
      required this.score,
      required this.selected,
      required this.message,
      required this.onSelect,
      required this.onSubmit});
  final DashCreativeChallenge challenge;
  final int round, score, selected;
  final String? message;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(11),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 22),
            child: Center(
                child: _CenterCard(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ROUND $round · DESIGN CHALLENGE',
                        style: AppText.label),
                    const SizedBox(height: 4),
                    Text(challenge.category, style: AppText.h2),
                    const SizedBox(height: 4),
                    Text(challenge.brief, style: AppText.caption),
                    const SizedBox(height: 8),
                    Text(challenge.question,
                        style: AppText.body.copyWith(color: AppColors.ink)),
                    const SizedBox(height: 7),
                    for (var i = 0; i < challenge.options.length; i++)
                      _ChallengeOptionTile(
                          option: challenge.options[i],
                          index: i,
                          selected: selected == i,
                          onTap: () => onSelect(i)),
                    if (message != null) ...[
                      const SizedBox(height: 5),
                      Text(message!,
                          style: AppText.caption
                              .copyWith(color: const Color(0xFFFFA1B5))),
                    ],
                    const SizedBox(height: 7),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: selected < 0 ? null : onSubmit,
                            icon: const Icon(Icons.check_rounded),
                            label: Text(message == null
                                ? 'Submit challenge'
                                : 'Try selected answer'))),
                    Align(
                        alignment: Alignment.centerRight,
                        child:
                            Text('RUN SCORE $score', style: AppText.caption)),
                  ]),
            )),
          ),
        ),
      );
}

class _ChallengeOptionTile extends StatelessWidget {
  const _ChallengeOptionTile(
      {required this.option,
      required this.index,
      required this.selected,
      required this.onTap});
  final DashChallengeOption option;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: GlassCard(
            selected: selected,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(children: [
              if (option.colors.isNotEmpty)
                Row(children: [
                  for (final color in option.colors)
                    Container(
                        width: 15,
                        height: 27,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                            color: color.color,
                            borderRadius: BorderRadius.circular(3)))
                ]),
              if (option.typeSample != null)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(option.typeSample!,
                        style: AppText.h3
                            .copyWith(color: AppColors.sky, fontSize: 15))),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(option.title,
                        style: AppText.h3.copyWith(fontSize: 13)),
                    Text(option.detail, style: AppText.caption)
                  ])),
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? AppColors.sky : AppColors.inkFaint),
            ]),
          ),
        ),
      );
}

class _SimpleOverlay extends StatelessWidget {
  const _SimpleOverlay(
      {required this.icon,
      required this.title,
      required this.message,
      required this.primary,
      required this.onPrimary,
      required this.secondary,
      required this.onSecondary});
  final IconData icon;
  final String title, message, primary, secondary;
  final VoidCallback onPrimary, onSecondary;
  @override
  Widget build(BuildContext context) => _CenterCard(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.sky, size: 42),
          const SizedBox(height: 8),
          Text(title, style: AppText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: AppText.body, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(primary))),
          TextButton(onPressed: onSecondary, child: Text(secondary)),
        ]),
      );
}

class _CenterCard extends StatelessWidget {
  const _CenterCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassCard(
                strong: true,
                selected: true,
                padding: const EdgeInsets.all(17),
                child: child),
          ),
        ),
      );
}

class _RunnerPainter extends CustomPainter {
  _RunnerPainter(
      {required this.engine,
      required Listenable repaint,
      required this.reducedEffects})
      : super(repaint: repaint);
  final MotionDashEngine engine;
  final bool reducedEffects;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF080C1C),
                Color(0xFF17143B),
                Color(0xFF090D1A)
              ]).createShader(bounds));
    final speedPhase =
        reducedEffects ? 0.0 : engine.elapsed * (1.5 + engine.speed);
    for (var i = 0; i < 15; i++) {
      final x = size.width * ((i * 47 % 97) / 100);
      final y0 = size.height * ((i * 31 % 89) / 100);
      final y = (y0 + speedPhase * (12 + i % 5)) % size.height;
      canvas.drawLine(
          Offset(x, y),
          Offset(x, y + 7 + i % 7),
          Paint()
            ..color = AppColors.sky.withAlpha(20 + i % 15)
            ..strokeWidth = 1);
    }
    final horizon = size.height * .11;
    final bottom = size.height * .98;
    final topHalf = size.width * .16;
    final bottomHalf = size.width * .49;
    final track = Path()
      ..moveTo(size.width / 2 - topHalf, horizon)
      ..lineTo(size.width / 2 + topHalf, horizon)
      ..lineTo(size.width / 2 + bottomHalf, bottom)
      ..lineTo(size.width / 2 - bottomHalf, bottom)
      ..close();
    canvas.drawPath(
        track,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF171D38),
                Color(0xFF252142),
                Color(0xFF13182C)
              ]).createShader(Rect.fromLTRB(size.width / 2 - topHalf, horizon,
              size.width / 2 + topHalf, bottom)));
    canvas.drawPath(
        track,
        Paint()
          ..color = AppColors.sky.withAlpha(100)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (var laneLine = 1; laneLine < 3; laneLine++) {
      final ratio = (laneLine - 1.5) / 1.5;
      canvas.drawLine(
          Offset(size.width / 2 + ratio * topHalf, horizon),
          Offset(size.width / 2 + ratio * bottomHalf, bottom),
          Paint()
            ..color = AppColors.sky.withAlpha(65)
            ..strokeWidth = 1);
    }
    _drawTrackTicks(
        canvas, size, horizon, bottom, topHalf, bottomHalf, speedPhase);
    for (var i = engine.nextEventIndex;
        i < math.min(engine.events.length, engine.nextEventIndex + 4);
        i++) {
      _drawEvent(canvas, size, engine.events[i], i - engine.nextEventIndex,
          horizon, bottom, topHalf, bottomHalf);
    }
    _drawCube(canvas, size, bottom, bottomHalf);
    _drawFeedback(canvas, size);
  }

  void _drawTrackTicks(Canvas canvas, Size size, double horizon, double bottom,
      double topHalf, double bottomHalf, double phase) {
    final paint = Paint()
      ..color = AppColors.violet.withAlpha(60)
      ..strokeWidth = 1;
    for (var i = 0; i < 9; i++) {
      final t = ((i / 8 + phase * .08) % 1);
      final y = horizon + (bottom - horizon) * t * t;
      final half = topHalf + (bottomHalf - topHalf) * t;
      canvas.drawLine(Offset(size.width / 2 - half, y),
          Offset(size.width / 2 + half, y), paint);
    }
  }

  void _drawEvent(Canvas canvas, Size size, RunnerEvent event, int ahead,
      double horizon, double bottom, double topHalf, double bottomHalf) {
    final delta = event.time - engine.elapsed;
    final progress = (1 - delta / engine.travelDuration).clamp(0.0, 1.12);
    if (progress < 0.025) return;
    final depth = progress.clamp(0.0, 1.0);
    final curve = depth * depth;
    final y = horizon + (bottom - horizon) * curve;
    final half = topHalf + (bottomHalf - topHalf) * curve;
    final laneW = half * 2 / 3;
    final boxH = 8 + 48 * curve;
    switch (event.type) {
      case RunnerEventType.matchingBoxes:
        for (var lane = 0; lane < 3; lane++) {
          final color = event.boxColors[lane].color;
          final centerX = size.width / 2 - half + laneW * (lane + .5);
          final rect = Rect.fromCenter(
              center: Offset(centerX, y), width: laneW * .78, height: boxH);
          final path = Path()
            ..moveTo(rect.left + boxH * .15, rect.top)
            ..lineTo(rect.right, rect.top)
            ..lineTo(rect.right - boxH * .15, rect.bottom)
            ..lineTo(rect.left, rect.bottom)
            ..close();
          if (!reducedEffects && ahead == 0) {
            canvas.drawPath(
                path,
                Paint()
                  ..color = color.withAlpha(45)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
          }
          canvas.drawPath(
              path,
              Paint()
                ..color =
                    color.withAlpha((75 + depth * 130).round().clamp(0, 255)));
          canvas.drawPath(
              path,
              Paint()
                ..color = color.withAlpha(230)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4);
          if (depth > .25) {
            _paintText(canvas, event.boxColors[lane].short,
                Offset(centerX - 9, y - 7), 10, color);
          }
          if (event.bonus && lane == _matchingLane(event)) {
            _paintText(canvas, '★', Offset(centerX - 6, y - boxH - 13), 13,
                const Color(0xFFFFD66E));
          }
        }
        _paintText(canvas, 'MATCH YOUR CUBE',
            Offset(size.width / 2 - 55, y - boxH * .8), 9, AppColors.offWhite);
      case RunnerEventType.colorGate:
        final pulse = reducedEffects ? 0.0 : math.sin(engine.elapsed * 3.4) * 3;
        final radius = 7 + depth * size.width * .2 + pulse;
        final center = Offset(size.width / 2, y);
        final color = event.gateColor!.color;
        canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = color.withAlpha(45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 12);
        canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        canvas.drawCircle(
            center,
            radius * .72,
            Paint()
              ..color = color.withAlpha(120)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        _paintText(canvas, 'SHIFT · ${event.gateColor!.label.toUpperCase()}',
            Offset(center.dx - 55, y - radius - 15), 9, color);
      case RunnerEventType.barrier:
        final lane = event.blockedLane!;
        final baseCenterX = size.width / 2 - half + laneW * (lane + .5);
        final centerX = event.moving && !reducedEffects
            ? baseCenterX +
                math.sin(engine.elapsed * 3.2 + event.time) * laneW * .12
            : baseCenterX;
        final block = Rect.fromCenter(
            center: Offset(centerX, y), width: laneW * .76, height: boxH * .75);
        final color =
            event.moving ? const Color(0xFFFFB84D) : const Color(0xFFFF668E);
        canvas.drawRRect(
            RRect.fromRectAndRadius(block, const Radius.circular(5)),
            Paint()..color = color.withAlpha(165));
        canvas.drawRRect(
            RRect.fromRectAndRadius(block, const Radius.circular(5)),
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        _paintText(
            canvas,
            event.moving ? 'MOVING · LANE ${lane + 1}' : 'SWITCH LANES',
            Offset(centerX - 50, y - boxH),
            9,
            color);
      case RunnerEventType.gap:
        final safe = event.safeLane!;
        for (var lane = 0; lane < 3; lane++) {
          final centerX = size.width / 2 - half + laneW * (lane + .5);
          final rect = Rect.fromCenter(
              center: Offset(centerX, y), width: laneW * .82, height: boxH);
          if (lane == safe) {
            canvas.drawRect(rect, Paint()..color = const Color(0x6656E8C4));
            canvas.drawRect(
                rect,
                Paint()
                  ..color = const Color(0xFF56E8C4)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2);
          } else {
            canvas.drawRect(rect, Paint()..color = const Color(0xDD070A14));
            canvas.drawRect(
                rect,
                Paint()
                  ..color = const Color(0xFFFF668E)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5);
            for (var mark = -1; mark <= 1; mark++) {
              canvas.drawLine(
                Offset(rect.left + rect.width * (mark + 1) / 3, rect.bottom),
                Offset(rect.left + rect.width * (mark + 2) / 3, rect.top),
                Paint()
                  ..color = const Color(0x66FF668E)
                  ..strokeWidth = 1,
              );
            }
          }
        }
        _paintText(
            canvas,
            'GAP · SAFE LANE ${safe + 1}',
            Offset(size.width / 2 - 58, y - boxH - 7),
            9,
            const Color(0xFF72F3CF));
      case RunnerEventType.finish:
        final center = Offset(size.width / 2, y);
        final radius = 8 + depth * size.width * .22;
        const color = Color(0xFF8E79FF);
        canvas.drawOval(
          Rect.fromCenter(
              center: center, width: radius * 2, height: radius * 1.3),
          Paint()
            ..color = color.withAlpha(55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: center, width: radius * 2, height: radius * 1.3),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        _paintText(canvas, 'FINISH', Offset(center.dx - 17, y - radius * .9),
            10, AppColors.offWhite);
    }
  }

  int _matchingLane(RunnerEvent event) =>
      event.boxColors.indexOf(event.requiredColor ?? engine.cubeColor);

  void _drawCube(Canvas canvas, Size size, double bottom, double half) {
    final laneW = half * 2 / 3;
    final centerX = size.width / 2 - half + laneW * (engine.lane + .5);
    final center = Offset(centerX, bottom - size.height * .115);
    final w = math.min(laneW * .40, 44.0);
    final h = w * .82;
    final shift = Offset(w * .30, -h * .28);
    final color = engine.cubeColor.color;
    final front = Path()
      ..moveTo(center.dx - w / 2, center.dy - h / 2)
      ..lineTo(center.dx + w / 2, center.dy - h / 2)
      ..lineTo(center.dx + w / 2, center.dy + h / 2)
      ..lineTo(center.dx - w / 2, center.dy + h / 2)
      ..close();
    final top = Path()
      ..moveTo(center.dx - w / 2, center.dy - h / 2)
      ..lineTo(center.dx - w / 2 + shift.dx, center.dy - h / 2 + shift.dy)
      ..lineTo(center.dx + w / 2 + shift.dx, center.dy - h / 2 + shift.dy)
      ..lineTo(center.dx + w / 2, center.dy - h / 2)
      ..close();
    final side = Path()
      ..moveTo(center.dx + w / 2, center.dy - h / 2)
      ..lineTo(center.dx + w / 2 + shift.dx, center.dy - h / 2 + shift.dy)
      ..lineTo(center.dx + w / 2 + shift.dx, center.dy + h / 2 + shift.dy)
      ..lineTo(center.dx + w / 2, center.dy + h / 2)
      ..close();
    for (var i = 3; i >= 1; i--) {
      final trail = Path()
        ..addRect(Rect.fromCenter(
            center: center.translate(0, i * 8),
            width: w * (1 + i * .13),
            height: h * .35));
      canvas.drawPath(trail, Paint()..color = color.withAlpha(25));
    }
    if (!reducedEffects) {
      canvas.drawPath(
          front,
          Paint()
            ..color = color.withAlpha(60)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }
    canvas.drawPath(top, Paint()..color = color.withAlpha(220));
    canvas.drawPath(side, Paint()..color = color.withAlpha(155));
    canvas.drawPath(front, Paint()..color = color);
    final edge = Paint()
      ..color = Colors.white.withAlpha(220)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(top, edge);
    canvas.drawPath(side, edge);
    canvas.drawPath(front, edge);
  }

  void _drawFeedback(Canvas canvas, Size size) {
    if (engine.feedbackTime <= 0) return;
    final color =
        engine.feedback.contains('WRONG') || engine.feedback.contains('HIT')
            ? const Color(0xFFFF789A)
            : engine.cubeColor.color;
    _paintText(canvas, engine.feedback,
        Offset(size.width / 2 - 90, size.height * .045), 12, color);
  }

  void _paintText(
      Canvas canvas, String text, Offset offset, double size, Color color) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                color: color,
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                shadows: reducedEffects
                    ? null
                    : [Shadow(color: color.withAlpha(120), blurRadius: 5)])),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 220);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _RunnerPainter oldDelegate) =>
      oldDelegate.engine != engine ||
      oldDelegate.reducedEffects != reducedEffects;
}

String _eventHint(RunnerEvent? event, CubeColor color) {
  if (event == null) return 'PORTAL AHEAD';
  return switch (event.type) {
    RunnerEventType.matchingBoxes => 'FIND ${color.label.toUpperCase()}',
    RunnerEventType.colorGate =>
      'GATE → ${event.gateColor!.label.toUpperCase()}',
    RunnerEventType.barrier => 'KEEP A LANE CLEAR',
    RunnerEventType.gap => 'SAFE LANE ${event.safeLane! + 1}',
    RunnerEventType.finish => 'FINISH PORTAL',
  };
}

extension CubeColorVisual on CubeColor {
  Color get color => switch (this) {
        CubeColor.blue => const Color(0xFF43A6FF),
        CubeColor.violet => const Color(0xFFAA73FF),
        CubeColor.cyan => const Color(0xFF45E8E2),
        CubeColor.green => const Color(0xFF65E793),
        CubeColor.yellow => const Color(0xFFFFDA62),
        CubeColor.orange => const Color(0xFFFFA554),
        CubeColor.magenta => const Color(0xFFF277D8),
        CubeColor.red => const Color(0xFFFF667E),
      };
  String get short => switch (this) {
        CubeColor.blue => 'BLU',
        CubeColor.violet => 'VIO',
        CubeColor.cyan => 'CYN',
        CubeColor.green => 'GRN',
        CubeColor.yellow => 'YLW',
        CubeColor.orange => 'ORG',
        CubeColor.magenta => 'MAG',
        CubeColor.red => 'RED',
      };
}
