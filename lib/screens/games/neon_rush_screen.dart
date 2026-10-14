import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/learning_progress_store.dart';
import '../../widgets/glass_card.dart';

enum _RunState { ready, running, paused, gameOver }

enum _EntityKind { barrier, beam, crate, orb, magnet, shield, slow, boost }

class _ArcadeEntity {
  _ArcadeEntity(this.id, this.lane, this.kind, {this.z = 0});
  final int id;
  final int lane;
  final _EntityKind kind;
  double z;
  bool handled = false;
}

class _GameWorld {
  int lane = 1;
  int energy = 0;
  double score = 0;
  double elapsed = 0;
  double spawnClock = 0;
  double jumpTime = 0;
  double slideTime = 0;
  double magnetTime = 0;
  double slowTime = 0;
  double boostTime = 0;
  double powerMessageTime = 0;
  String powerMessage = '';
  bool shieldCharged = false;
  final List<_ArcadeEntity> entities = [];
  int nextId = 0;

  int get environment => (elapsed ~/ 20).clamp(0, 2);
  int get level => environment + 1;
}

class _HudSnapshot {
  const _HudSnapshot({
    required this.score,
    required this.energy,
    required this.best,
    required this.level,
    required this.shield,
    required this.activePower,
  });
  final int score;
  final int energy;
  final int best;
  final int level;
  final bool shield;
  final String activePower;
}

class NeonRushScreen extends StatefulWidget {
  const NeonRushScreen({super.key});
  @override
  State<NeonRushScreen> createState() => _NeonRushScreenState();
}

class _NeonRushScreenState extends State<NeonRushScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _store = LearningProgressStore.instance;
  final _world = _GameWorld();
  final _random = math.Random();
  final _frame = ValueNotifier<int>(0);
  final _hud = ValueNotifier<_HudSnapshot>(const _HudSnapshot(
    score: 0,
    energy: 0,
    best: 0,
    level: 1,
    shield: false,
    activePower: '',
  ));

  late final Ticker _ticker = createTicker(_tick);
  _RunState _state = _RunState.ready;
  Duration? _lastTick;
  int _best = 0;
  bool _tutorialSeen = false;
  bool _sound = false;
  bool _haptics = false;
  bool _reducedEffects = false;
  bool _loading = true;
  String _trail = 'blue';
  int _lastHudSecond = -1;
  List<int> _history = [];
  final List<String> _newAchievements = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait<Object>([
      _store.neonRushBest,
      _store.getNeonRushOption('tutorial_seen'),
      _store.getNeonRushOption('sound'),
      _store.getNeonRushOption('haptics'),
      _store.getNeonRushOption('reduced_effects'),
      _store.neonRushTrail,
      _store.neonRushHistory,
    ]);
    if (!mounted) return;
    setState(() {
      _best = results[0] as int;
      _tutorialSeen = results[1] as bool;
      _sound = results[2] as bool;
      _haptics = results[3] as bool;
      _reducedEffects = results[4] as bool;
      _trail = results[5] as String;
      _history = results[6] as List<int>;
      _loading = false;
    });
    _publishHud();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frame.dispose();
    _hud.dispose();
    super.dispose();
  }

  void _start() {
    _resetWorld();
    setState(() => _state = _RunState.running);
    _lastTick = null;
    _ticker.start();
  }

  void _resetWorld() {
    _world
      ..lane = 1
      ..energy = 0
      ..score = 0
      ..elapsed = 0
      ..spawnClock = .35
      ..jumpTime = 0
      ..slideTime = 0
      ..magnetTime = 0
      ..slowTime = 0
      ..boostTime = 0
      ..powerMessageTime = 0
      ..powerMessage = ''
      ..shieldCharged = false
      ..entities.clear()
      ..nextId = 0;
    _lastHudSecond = -1;
    _newAchievements.clear();
    _publishHud();
    _frame.value++;
  }

  void _tick(Duration elapsed) {
    if (_state != _RunState.running) return;
    final dt = _lastTick == null
        ? 1 / 60
        : ((elapsed - _lastTick!).inMicroseconds / 1000000).clamp(0.0, .05);
    _lastTick = elapsed;
    if (dt <= 0) return;

    _world.elapsed += dt;
    _world.jumpTime = math.max(0, _world.jumpTime - dt);
    _world.slideTime = math.max(0, _world.slideTime - dt);
    _world.magnetTime = math.max(0, _world.magnetTime - dt);
    _world.slowTime = math.max(0, _world.slowTime - dt);
    _world.boostTime = math.max(0, _world.boostTime - dt);
    _world.powerMessageTime = math.max(0, _world.powerMessageTime - dt);

    final speed =
        (.58 + _world.elapsed * .012) * (_world.slowTime > 0 ? .55 : 1);
    _world.score += dt * 8 * (_world.boostTime > 0 ? 2 : 1);
    _world.spawnClock += dt;
    final spawnEvery = math.max(.48, 1.12 - _world.elapsed * .009);
    if (_world.spawnClock >= spawnEvery) {
      _world.spawnClock -= spawnEvery;
      _spawnPattern();
    }

    for (final entity in _world.entities) {
      final oldZ = entity.z;
      entity.z += dt * speed;
      if (entity.handled) continue;
      if (entity.kind == _EntityKind.orb &&
          _world.magnetTime > 0 &&
          entity.z >= .52) {
        _collect(entity);
      } else if (oldZ < .88 && entity.z >= .88) {
        _resolveEntity(entity);
      }
    }
    _world.entities.removeWhere((entity) => entity.handled || entity.z > 1.08);
    _frame.value++;

    final seconds = _world.elapsed.floor();
    if (seconds != _lastHudSecond) {
      _lastHudSecond = seconds;
      _publishHud();
    }
    if (_world.elapsed >= 20 && _world.elapsed - dt < 20) {
      _showLevelToast('CYBER TUNNEL');
    } else if (_world.elapsed >= 40 && _world.elapsed - dt < 40) {
      _showLevelToast('COSMIC GRID');
    }
  }

  void _spawnPattern() {
    final lane = _random.nextInt(3);
    final roll = _random.nextDouble();
    late final _EntityKind obstacle;
    if (roll < .48) {
      obstacle = _EntityKind.crate;
    } else if (roll < .73) {
      obstacle = _EntityKind.barrier;
    } else {
      obstacle = _EntityKind.beam;
    }
    _world.entities.add(_ArcadeEntity(_world.nextId++, lane, obstacle));

    // Early patterns leave at least one clear lane; speed raises difficulty gradually.
    if (_world.elapsed > 12 && _random.nextDouble() < .22) {
      var secondLane = _random.nextInt(3);
      while (secondLane == lane) {
        secondLane = _random.nextInt(3);
      }
      _world.entities.add(_ArcadeEntity(
        _world.nextId++,
        secondLane,
        _random.nextBool() ? _EntityKind.crate : _EntityKind.barrier,
        z: -.1,
      ));
    }

    if (_random.nextDouble() < .84) {
      final orbLane = _random.nextInt(3);
      _world.entities.add(_ArcadeEntity(
        _world.nextId++,
        orbLane,
        _EntityKind.orb,
        z: -.25,
      ));
    }
    if (_random.nextDouble() < .09) {
      const powers = [
        _EntityKind.magnet,
        _EntityKind.shield,
        _EntityKind.slow,
        _EntityKind.boost,
      ];
      _world.entities.add(_ArcadeEntity(
        _world.nextId++,
        _random.nextInt(3),
        powers[_random.nextInt(powers.length)],
        z: -.42,
      ));
    }
  }

  void _resolveEntity(_ArcadeEntity entity) {
    if (entity.kind == _EntityKind.orb) {
      if (entity.lane == _world.lane) _collect(entity);
      return;
    }
    if (_isPower(entity.kind)) {
      if (entity.lane == _world.lane) _activatePower(entity);
      return;
    }
    if (entity.lane != _world.lane) return;
    final avoided = switch (entity.kind) {
      _EntityKind.barrier => _world.jumpTime > 0,
      _EntityKind.beam => _world.slideTime > 0,
      _EntityKind.crate => false,
      _ => true,
    };
    if (avoided) return;
    if (_world.shieldCharged) {
      _world.shieldCharged = false;
      entity.handled = true;
      _showLevelToast('SHIELD USED');
      _feedback(collision: false);
      return;
    }
    _feedback(collision: true);
    _endRun();
  }

  bool _isPower(_EntityKind kind) => const {
        _EntityKind.magnet,
        _EntityKind.shield,
        _EntityKind.slow,
        _EntityKind.boost,
      }.contains(kind);

  void _collect(_ArcadeEntity entity) {
    if (entity.handled) return;
    entity.handled = true;
    _world.energy++;
    _world.score += 25 * (_world.boostTime > 0 ? 2 : 1);
    _feedback(collect: true);
    if (_world.energy >= 10) _unlockAchievement('orb_collector');
    if (_world.energy >= 50) _unlockAchievement('energy_hunter');
  }

  void _activatePower(_ArcadeEntity entity) {
    entity.handled = true;
    switch (entity.kind) {
      case _EntityKind.magnet:
        _world.magnetTime = 7;
        _world.powerMessage = 'ENERGY MAGNET · 7s';
      case _EntityKind.shield:
        _world.shieldCharged = true;
        _world.powerMessage = 'SHIELD CHARGED · 1 HIT';
      case _EntityKind.slow:
        _world.slowTime = 5;
        _world.powerMessage = 'SLOW MOTION · 5s';
      case _EntityKind.boost:
        _world.boostTime = 8;
        _world.powerMessage = 'ENERGY BOOST · 2× SCORE';
      default:
        return;
    }
    _world.powerMessageTime = 1.7;
    _feedback(powerUp: true);
    _publishHud();
  }

  void _moveLane(int direction) {
    if (_state != _RunState.running) return;
    final next = (_world.lane + direction).clamp(0, 2);
    if (next != _world.lane) {
      _world.lane = next;
      _feedback(move: true);
      _frame.value++;
    }
  }

  void _jump() {
    if (_state != _RunState.running) return;
    _world.jumpTime = .72;
    _feedback(move: true, jump: true);
    _frame.value++;
  }

  void _slide() {
    if (_state != _RunState.running) return;
    _world.slideTime = .68;
    _feedback(move: true);
    _frame.value++;
  }

  void _pause() {
    if (_state != _RunState.running) return;
    _ticker.stop();
    _lastTick = null;
    if (mounted) setState(() => _state = _RunState.paused);
  }

  void _resume() {
    if (_state != _RunState.paused) return;
    setState(() => _state = _RunState.running);
    _lastTick = null;
    _ticker.start();
  }

  Future<void> _endRun() async {
    if (_state != _RunState.running) return;
    _ticker.stop();
    _lastTick = null;
    final score = _world.score.floor();
    setState(() => _state = _RunState.gameOver);
    await _store.recordNeonRushRun(score);
    final newBest = await _store.neonRushBest;
    final history = await _store.neonRushHistory;
    if (score >= 250) await _unlockAchievement('score_250');
    if (_world.elapsed >= 60) await _unlockAchievement('survivor_60');
    if (!mounted) return;
    setState(() {
      _best = newBest;
      _history = history;
    });
    _publishHud();
  }

  Future<void> _unlockAchievement(String id) async {
    final isNew = await _store.unlockNeonRushAchievement(id);
    if (isNew && mounted && !_newAchievements.contains(id)) {
      setState(() => _newAchievements.add(id));
    }
  }

  void _publishHud() {
    _hud.value = _HudSnapshot(
      score: _world.score.floor(),
      energy: _world.energy,
      best: _best,
      level: _world.level,
      shield: _world.shieldCharged,
      activePower: _world.magnetTime > 0
          ? 'MAGNET'
          : _world.slowTime > 0
              ? 'SLOW'
              : _world.boostTime > 0
                  ? '2× SCORE'
                  : '',
    );
  }

  void _showLevelToast(String message) {
    _world.powerMessage = message;
    _world.powerMessageTime = 1.4;
    _frame.value++;
  }

  void _feedback(
      {bool collect = false,
      bool powerUp = false,
      bool collision = false,
      bool move = false,
      bool jump = false}) {
    if (_sound && (collect || powerUp || collision || jump)) {
      SystemSound.play(
          collision ? SystemSoundType.alert : SystemSoundType.click);
    }
    if (_haptics) {
      if (collision) {
        HapticFeedback.heavyImpact();
      } else if (collect || powerUp) {
        HapticFeedback.lightImpact();
      } else if (move) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _swipeHorizontal(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 100) return;
    _moveLane(velocity < 0 ? -1 : 1);
  }

  void _swipeVertical(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -100) {
      _jump();
    } else if (velocity > 100) {
      _slide();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _moveLane(-1);
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _moveLane(1);
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.space:
        _jump();
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        _slide();
      case LogicalKeyboardKey.escape:
        _pause();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Game settings', style: AppText.h2),
            SwitchListTile(
              title: const Text('Sound effects'),
              subtitle: const Text(
                  'Uses short system sound cues; custom audio files are not included.'),
              value: _sound,
              onChanged: (value) async {
                setState(() => _sound = value);
                setModalState(() {});
                await _store.setNeonRushOption('sound', value);
              },
            ),
            SwitchListTile(
              title: const Text('Haptics'),
              value: _haptics,
              onChanged: (value) async {
                setState(() => _haptics = value);
                setModalState(() {});
                await _store.setNeonRushOption('haptics', value);
              },
            ),
            SwitchListTile(
              title: const Text('Reduce visual effects'),
              subtitle: const Text('Fewer trails and decorative stars.'),
              value: _reducedEffects,
              onChanged: (value) async {
                setState(() => _reducedEffects = value);
                setModalState(() {});
                _frame.value++;
                await _store.setNeonRushOption('reduced_effects', value);
              },
            ),
            const Divider(),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Energy trail', style: AppText.h3)),
            const SizedBox(height: 5),
            Wrap(spacing: 8, children: [
              for (final choice in const [
                ('blue', 'Blue · default', 0),
                ('violet', 'Violet · 250 best', 250),
                ('gold', 'Gold · 1000 best', 1000),
              ])
                ChoiceChip(
                  label: Text(choice.$2),
                  selected: _trail == choice.$1,
                  onSelected: _best >= choice.$3
                      ? (_) async {
                          setState(() => _trail = choice.$1);
                          setModalState(() {});
                          await _store.setNeonRushTrail(choice.$1);
                        }
                      : null,
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('AM Arcade · Neon Rush'),
            actions: [
              IconButton(
                tooltip: _state == _RunState.running
                    ? 'Pause game'
                    : 'Game settings',
                onPressed: _state == _RunState.running ? _pause : _showSettings,
                icon: Icon(_state == _RunState.running
                    ? Icons.pause_rounded
                    : Icons.tune_rounded),
              ),
              if (_state == _RunState.paused)
                IconButton(
                    onPressed: _resume,
                    tooltip: 'Resume game',
                    icon: const Icon(Icons.play_arrow_rounded)),
            ],
          ),
          body: SafeArea(
            top: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: ValueListenableBuilder<_HudSnapshot>(
                        valueListenable: _hud,
                        builder: (context, hud, _) => _HudRow(hud: hud),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        final size =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        return Stack(fit: StackFit.expand, children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: _swipeHorizontal,
                            onVerticalDragEnd: _swipeVertical,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: size,
                                painter: _NeonRushPainter(
                                  world: _world,
                                  repaint: _frame,
                                  reducedEffects: _reducedEffects,
                                  trail: _trail,
                                ),
                              ),
                            ),
                          ),
                          if (_state == _RunState.running)
                            _PowerBanner(world: _world, repaint: _frame),
                          if (_state == _RunState.ready)
                            _ReadyOverlay(
                              best: _best,
                              firstRun: !_tutorialSeen,
                              onPlay: () async {
                                await _store.setNeonRushOption(
                                    'tutorial_seen', true);
                                if (mounted) {
                                  setState(() => _tutorialSeen = true);
                                  _start();
                                }
                              },
                            ),
                          if (_state == _RunState.paused)
                            _CenterOverlay(
                              title: 'Paused',
                              subtitle:
                                  'Your run is waiting right where you left it.',
                              primary: 'Resume',
                              onPrimary: _resume,
                              secondary: 'Restart run',
                              onSecondary: _start,
                            ),
                          if (_state == _RunState.gameOver)
                            _GameOverOverlay(
                              score: _world.score.floor(),
                              best: _best,
                              energy: _world.energy,
                              level: _world.level,
                              history: _history,
                              achievements: _newAchievements,
                              onRestart: _start,
                            ),
                        ]);
                      }),
                    ),
                    if (_state == _RunState.running)
                      _TouchControls(
                        onLeft: () => _moveLane(-1),
                        onRight: () => _moveLane(1),
                        onJump: _jump,
                        onSlide: _slide,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                        child: Text(
                          _state == _RunState.ready
                              ? 'Swipe to move · use buttons or arrow keys too'
                              : _state == _RunState.gameOver
                                  ? 'Trail ${_trail.toUpperCase()} · best trail unlocks in settings'
                                  : 'Tap Resume or press Escape to continue',
                          textAlign: TextAlign.center,
                          style: AppText.caption,
                        ),
                      ),
                  ]),
          ),
        ),
      );
}

class _HudRow extends StatelessWidget {
  const _HudRow({required this.hud});
  final _HudSnapshot hud;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: _HudPill(
                label: 'SCORE', value: hud.score.toString().padLeft(4, '0'))),
        const SizedBox(width: 6),
        Expanded(child: _HudPill(label: 'ENERGY', value: '✦ ${hud.energy}')),
        const SizedBox(width: 6),
        Expanded(
            child: _HudPill(
                label: 'BEST · LV ${hud.level}', value: hud.best.toString())),
        if (hud.shield || hud.activePower.isNotEmpty) ...[
          const SizedBox(width: 6),
          Icon(hud.shield ? Icons.shield_rounded : Icons.bolt_rounded,
              color: AppColors.sky, size: 21),
        ],
      ]);
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: .84),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppText.label.copyWith(fontSize: 8, letterSpacing: 1)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.h3
                      .copyWith(fontSize: 15, color: AppColors.offWhite)),
            ]),
      );
}

class _ReadyOverlay extends StatelessWidget {
  const _ReadyOverlay(
      {required this.best, required this.firstRun, required this.onPlay});
  final int best;
  final bool firstRun;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: GlassCard(
            strong: true,
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, gradient: AppColors.brandGradient),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 31),
              ),
              const SizedBox(height: 11),
              Text('NEON RUSH', style: AppText.mark(32, spacing: 3)),
              Text('Run the lightline. Stay in motion.',
                  textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: 13),
              if (firstRun) ...[
                const _RuleRow(
                    icon: Icons.swipe,
                    text: 'Swipe left/right to switch lanes.'),
                const _RuleRow(
                    icon: Icons.arrow_upward_rounded,
                    text: 'Jump over low barriers.'),
                const _RuleRow(
                    icon: Icons.arrow_downward_rounded,
                    text: 'Slide below overhead beams.'),
                const _RuleRow(
                    icon: Icons.auto_awesome,
                    text: 'Collect energy; powers help for a short time.'),
              ] else
                Text('Best score · $best',
                    style: AppText.h3.copyWith(color: AppColors.sky)),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start running'))),
            ]),
          ),
        ),
      );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, color: AppColors.sky, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.caption))
        ]),
      );
}

class _CenterOverlay extends StatelessWidget {
  const _CenterOverlay(
      {required this.title,
      required this.subtitle,
      required this.primary,
      required this.onPrimary,
      required this.secondary,
      required this.onSecondary});
  final String title, subtitle, primary, secondary;
  final VoidCallback onPrimary, onSecondary;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            strong: true,
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: AppText.h1),
              const SizedBox(height: 5),
              Text(subtitle, textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: 13),
              SizedBox(
                  width: double.infinity,
                  child:
                      FilledButton(onPressed: onPrimary, child: Text(primary))),
              TextButton(onPressed: onSecondary, child: Text(secondary)),
            ]),
          ),
        ),
      );
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay(
      {required this.score,
      required this.best,
      required this.energy,
      required this.level,
      required this.history,
      required this.achievements,
      required this.onRestart});
  final int score, best, energy, level;
  final List<int> history;
  final List<String> achievements;
  final VoidCallback onRestart;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            strong: true,
            padding: const EdgeInsets.all(19),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt_rounded, color: AppColors.sky, size: 35),
              Text('Run complete', style: AppText.h1),
              const SizedBox(height: 4),
              Text('Score  $score',
                  style: AppText.h2.copyWith(color: AppColors.sky)),
              Text('Best  $best   ·   Energy  $energy   ·   Level $level',
                  textAlign: TextAlign.center, style: AppText.caption),
              if (achievements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('NEW ACHIEVEMENT', style: AppText.label),
                Text(achievements.map(_achievementLabel).join(' · '),
                    textAlign: TextAlign.center, style: AppText.body),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text('Recent scores · ${history.take(5).join('   ')}',
                    style: AppText.caption),
              ],
              const SizedBox(height: 11),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: onRestart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Run again'))),
            ]),
          ),
        ),
      );

  String _achievementLabel(String id) => switch (id) {
        'orb_collector' => 'Orb collector',
        'energy_hunter' => 'Energy hunter',
        'score_250' => '250 score',
        'survivor_60' => '60-second survivor',
        _ => id,
      };
}

class _TouchControls extends StatelessWidget {
  const _TouchControls(
      {required this.onLeft,
      required this.onRight,
      required this.onJump,
      required this.onSlide});
  final VoidCallback onLeft, onRight, onJump, onSlide;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(children: [
          _ControlButton(
              icon: Icons.chevron_left_rounded,
              label: 'LEFT',
              onPressed: onLeft),
          const SizedBox(width: 6),
          _ControlButton(
              icon: Icons.arrow_upward_rounded,
              label: 'JUMP',
              onPressed: onJump),
          const SizedBox(width: 6),
          _ControlButton(
              icon: Icons.arrow_downward_rounded,
              label: 'SLIDE',
              onPressed: onSlide),
          const SizedBox(width: 6),
          _ControlButton(
              icon: Icons.chevron_right_rounded,
              label: 'RIGHT',
              onPressed: onRight),
        ]),
      );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton(
      {required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Expanded(
        child: SizedBox(
          height: 58,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              side: const BorderSide(color: AppColors.glassBorderStrong),
              backgroundColor: AppColors.navy.withValues(alpha: .72),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 21, color: AppColors.sky),
              Text(label,
                  style:
                      AppText.label.copyWith(fontSize: 8, letterSpacing: .7)),
            ]),
          ),
        ),
      );
}

class _PowerBanner extends StatelessWidget {
  const _PowerBanner({required this.world, required this.repaint});
  final _GameWorld world;
  final Listenable repaint;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: repaint,
        builder: (context, _) => IgnorePointer(
          child: AnimatedOpacity(
            opacity: world.powerMessageTime > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Align(
              alignment: const Alignment(0, -.58),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.sky.withValues(alpha: .55)),
                ),
                child: Text(world.powerMessage,
                    style: AppText.label.copyWith(letterSpacing: 1)),
              ),
            ),
          ),
        ),
      );
}

class _NeonRushPainter extends CustomPainter {
  _NeonRushPainter(
      {required this.world,
      required Listenable repaint,
      required this.reducedEffects,
      required this.trail})
      : super(repaint: repaint);
  final _GameWorld world;
  final bool reducedEffects;
  final String trail;

  Color get _accent => switch (world.environment) {
        0 => const Color(0xFF52C7FF),
        1 => const Color(0xFF49F0D1),
        _ => const Color(0xFFC18BFF),
      };
  Color get _secondary => switch (world.environment) {
        0 => const Color(0xFF735BFF),
        1 => const Color(0xFF1979B8),
        _ => const Color(0xFFFC61D8),
      };

  double _roadHalfWidth(Size size, double z) => size.width * (.16 + .31 * z);
  double _laneX(Size size, int lane, double z) =>
      size.width / 2 + (lane - 1) * _roadHalfWidth(size, z) * .67;
  double _depthY(Size size, double z) =>
      size.height * .19 + math.pow(z.clamp(0, 1), 1.7) * size.height * .70;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF090D1D),
          _secondary.withValues(alpha: .21),
          const Color(0xFF080D1B)
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);
    _drawHorizon(canvas, size);
    _drawTrack(canvas, size);
    if (!reducedEffects) _drawStars(canvas, size);
    for (final entity in world.entities) {
      if (!entity.handled) _drawEntity(canvas, size, entity);
    }
    _drawPlayer(canvas, size);
  }

  void _drawHorizon(Canvas canvas, Size size) {
    final horizonY = size.height * .2;
    final glow = Paint()
      ..shader = RadialGradient(
              colors: [_accent.withValues(alpha: .22), Colors.transparent])
          .createShader(Rect.fromCircle(
              center: Offset(size.width / 2, horizonY),
              radius: size.width * .6));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * .55), glow);
    final line = Paint()
      ..color = _accent.withValues(alpha: .55)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(size.width * .12, horizonY),
        Offset(size.width * .88, horizonY), line);
    if (world.environment == 1) {
      final ringPaint = Paint()
        ..color = _secondary.withValues(alpha: .24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (var i = 0; i < 4; i++) {
        final f = ((i / 4 + world.elapsed * .07) % 1);
        final radius = size.width * (.12 + f * .53);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(size.width / 2, horizonY),
                width: radius * 2,
                height: radius * .55),
            ringPaint);
      }
    }
  }

  void _drawTrack(Canvas canvas, Size size) {
    final horizonY = size.height * .2;
    final topHalf = _roadHalfWidth(size, 0);
    final bottomHalf = _roadHalfWidth(size, 1);
    final road = Path()
      ..moveTo(size.width / 2 - topHalf, horizonY)
      ..lineTo(size.width / 2 + topHalf, horizonY)
      ..lineTo(size.width / 2 + bottomHalf, size.height)
      ..lineTo(size.width / 2 - bottomHalf, size.height)
      ..close();
    canvas.drawPath(
        road, Paint()..color = const Color(0xFF0D1730).withValues(alpha: .83));
    final edge = Paint()
      ..color = _accent.withValues(alpha: .72)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.width / 2 - topHalf, horizonY),
        Offset(size.width / 2 - bottomHalf, size.height), edge);
    canvas.drawLine(Offset(size.width / 2 + topHalf, horizonY),
        Offset(size.width / 2 + bottomHalf, size.height), edge);
    final lanePaint = Paint()
      ..color = _accent.withValues(alpha: .2)
      ..strokeWidth = 1;
    for (final side in [-1, 1]) {
      canvas.drawLine(
        Offset(size.width / 2 + side * topHalf / 3, horizonY),
        Offset(size.width / 2 + side * bottomHalf / 3, size.height),
        lanePaint,
      );
    }
    final scroll = (world.elapsed * (.9 + world.elapsed * .009)) % 1;
    for (var i = 0; i < 9; i++) {
      final z = (i / 9 + scroll) % 1;
      final y = _depthY(size, z);
      final half = _roadHalfWidth(size, z);
      final alpha = (.08 + z * .32).clamp(0.0, .4);
      final marker = Paint()
        ..color = _accent.withValues(alpha: alpha)
        ..strokeWidth = 1 + 2 * z;
      canvas.drawLine(Offset(size.width / 2 - half * .92, y),
          Offset(size.width / 2 + half * .92, y), marker);
    }
    if (world.slowTime > 0) {
      final slowPaint = Paint()
        ..color = const Color(0xFF9F8AFF).withValues(alpha: .17)
        ..strokeWidth = 4;
      for (var i = 0; i < 4; i++) {
        final z = (i / 4 + scroll * .6) % 1;
        final y = _depthY(size, z);
        canvas.drawLine(Offset(size.width * .12, y),
            Offset(size.width * .88, y), slowPaint);
      }
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    for (var i = 0; i < 10; i++) {
      final xSeed = (i * 47.17) % 1;
      final y = ((i * .137 + world.elapsed * (.05 + i * .004)) % 1) *
          size.height *
          .45;
      final x = xSeed * size.width;
      final radius = (i % 3 + 1) * .7;
      canvas.drawCircle(Offset(x, y), radius,
          Paint()..color = _accent.withValues(alpha: .28));
    }
  }

  void _drawEntity(Canvas canvas, Size size, _ArcadeEntity entity) {
    final z = entity.z.clamp(0.0, 1.0);
    final x = _laneX(size, entity.lane, z);
    final y = _depthY(size, z);
    final scale = .4 + z * .9;
    if (entity.kind == _EntityKind.orb) {
      final radius = 6 + z * 8;
      final color = _worldBoosted() ? const Color(0xFFFFD65E) : _accent;
      final shader = Paint()
        ..shader = RadialGradient(
                colors: [Colors.white, color, color.withValues(alpha: .05)])
            .createShader(Rect.fromCircle(
                center: Offset(x, y - radius * .3), radius: radius * 1.6));
      canvas.drawCircle(Offset(x, y - radius * .3), radius * 1.6, shader);
      canvas.drawCircle(Offset(x, y - radius * .3), radius * .5,
          Paint()..color = Colors.white.withValues(alpha: .9));
      return;
    }
    if (_isPowerEntity(entity.kind)) {
      final color = switch (entity.kind) {
        _EntityKind.magnet => const Color(0xFF58D5FF),
        _EntityKind.shield => const Color(0xFF67E7A3),
        _EntityKind.slow => const Color(0xFFAF8CFF),
        _ => const Color(0xFFFFCF62),
      };
      final radius = 10 * scale;
      canvas.drawCircle(Offset(x, y - radius), radius * 1.4,
          Paint()..color = color.withValues(alpha: .14));
      canvas.drawCircle(Offset(x, y - radius), radius, Paint()..color = color);
      final icon = switch (entity.kind) {
        _EntityKind.magnet => Icons.auto_awesome,
        _EntityKind.shield => Icons.shield_rounded,
        _EntityKind.slow => Icons.hourglass_bottom_rounded,
        _ => Icons.bolt_rounded,
      };
      final painter = TextPainter(
          text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                  fontSize: 13 * scale,
                  fontFamily: icon.fontFamily,
                  package: icon.fontPackage,
                  color: const Color(0xFF10162A))),
          textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(canvas,
          Offset(x - painter.width / 2, y - radius - painter.height / 2));
      return;
    }
    final laneWidth = _roadHalfWidth(size, z) * .66;
    final width = laneWidth * .74;
    final height = (13 + z * 23) * scale;
    final rect = Rect.fromCenter(
        center: Offset(x, y - height * .43), width: width, height: height);
    final color = entity.kind == _EntityKind.beam
        ? const Color(0xFFFF6AA8)
        : entity.kind == _EntityKind.barrier
            ? const Color(0xFFFFBA58)
            : const Color(0xFFFA5F79);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.inflate(2 * scale), Radius.circular(5 * scale)),
        Paint()..color = color.withValues(alpha: .17));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(4 * scale)),
        Paint()..color = color);
    final stripe = Paint()
      ..color = const Color(0xFF24162B).withValues(alpha: .7)
      ..strokeWidth = 2 * scale;
    if (entity.kind == _EntityKind.barrier) {
      for (var i = -1; i <= 1; i++) {
        canvas.drawLine(Offset(x + i * width / 4, rect.top + 2),
            Offset(x + i * width / 4 + 6 * scale, rect.bottom - 2), stripe);
      }
    } else if (entity.kind == _EntityKind.beam) {
      canvas.drawLine(Offset(rect.left + 3, rect.center.dy),
          Offset(rect.right - 3, rect.center.dy), stripe);
    }
  }

  bool _worldBoosted() => world.boostTime > 0;
  bool _isPowerEntity(_EntityKind kind) => const {
        _EntityKind.magnet,
        _EntityKind.shield,
        _EntityKind.slow,
        _EntityKind.boost,
      }.contains(kind);

  void _drawPlayer(Canvas canvas, Size size) {
    final x = _laneX(size, world.lane, .91);
    final jump = world.jumpTime > 0
        ? math.sin((world.jumpTime / .72) * math.pi) * size.height * .12
        : 0.0;
    final slide = world.slideTime > 0;
    final y = size.height * .86 - jump;
    final color = trail == 'gold'
        ? const Color(0xFFFFD65E)
        : trail == 'violet'
            ? const Color(0xFFBA8BFF)
            : _accent;
    if (!reducedEffects) {
      final streak = Paint()
        ..color = color.withValues(alpha: .15)
        ..strokeWidth = 3;
      for (var i = 0; i < 5; i++) {
        final dx = math.sin(world.elapsed * 9 + i) * (9 + i * 2);
        canvas.drawLine(Offset(x + dx, y + 9 + i * 5),
            Offset(x + dx * 1.3, y + 24 + i * 8), streak);
      }
    }
    final bodyHeight = slide ? 15.0 : 34.0;
    final body = Rect.fromCenter(
        center: Offset(x, y + (slide ? 5 : 0)),
        width: slide ? 37 : 23,
        height: bodyHeight);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body.inflate(7), const Radius.circular(18)),
        Paint()..color = color.withValues(alpha: .16));
    final bodyPaint = Paint()
      ..shader = LinearGradient(colors: [Colors.white, color, _secondary])
          .createShader(body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(11)), bodyPaint);
    if (!slide) {
      canvas.drawCircle(
          Offset(x, y - 22), 8, Paint()..color = const Color(0xFFEAF7FF));
      final visor = Paint()..color = _secondary;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(x + 2, y - 22), width: 9, height: 4),
              const Radius.circular(3)),
          visor);
    }
    final foot = Paint()
      ..color = color.withValues(alpha: .75)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - 5, y + 13), Offset(x - 9, y + 19), foot);
    canvas.drawLine(Offset(x + 5, y + 13), Offset(x + 9, y + 19), foot);
  }

  @override
  bool shouldRepaint(covariant _NeonRushPainter oldDelegate) =>
      oldDelegate.world != world ||
      oldDelegate.reducedEffects != reducedEffects ||
      oldDelegate.trail != trail;
}
