import 'dart:math' as math;

enum MotionDashState {
  ready,
  countdown,
  running,
  paused,
  challenge,
  roundComplete,
  gameOver,
}

enum CubeColor { blue, violet, cyan, green, yellow, orange, magenta, red }

enum RunnerEventType { colorGate, matchingBoxes, barrier, gap, finish }

class RunnerEvent {
  const RunnerEvent({
    required this.time,
    required this.type,
    this.boxColors = const [],
    this.requiredColor,
    this.gateColor,
    this.blockedLane,
    this.safeLane,
    this.moving = false,
    this.bonus = false,
  });

  final double time;
  final RunnerEventType type;
  final List<CubeColor> boxColors;
  final CubeColor? requiredColor;
  final CubeColor? gateColor;
  final int? blockedLane;
  final int? safeLane;
  final bool moving;
  final bool bonus;
}

class DashChallengeOption {
  const DashChallengeOption({
    required this.title,
    required this.detail,
    this.colors = const [],
    this.typeSample,
  });

  final String title;
  final String detail;
  final List<CubeColor> colors;
  final String? typeSample;
}

class DashCreativeChallenge {
  const DashCreativeChallenge({
    required this.category,
    required this.brief,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  final String category;
  final String brief;
  final String question;
  final List<DashChallengeOption> options;
  final int answer;
  final String explanation;
}

/// Deterministic simulation and scoring for Motion Dash / Color Cube Runner.
class MotionDashEngine {
  MotionDashState state = MotionDashState.ready;
  int round = 1;
  int unlockedRound = 1;
  int completedRounds = 0;
  int score = 0;
  int combo = 0;
  int mistakes = 0;
  int lane = 1;
  int passedObstacles = 0;
  int nextEventIndex = 0;
  double elapsed = 0;
  double countdown = 3;
  double feedbackTime = 0;
  double colorPulse = 0;
  String feedback = 'READY';
  CubeColor cubeColor = CubeColor.blue;
  List<RunnerEvent> events = const [];
  MotionDashState _pausedFrom = MotionDashState.running;

  RunnerEvent? get nextEvent =>
      nextEventIndex < events.length ? events[nextEventIndex] : null;
  double get speed => 1 + math.min(round - 1, 20) * .025;
  double get travelDuration => 3.0 / speed;
  double get roundProgress => nextEvent == null
      ? 1
      : ((elapsed - (nextEvent!.time - travelDuration)) / travelDuration)
          .clamp(0.0, 1.0);
  String get roundName => 'ROUND $round';
  int get multiplier => 1 + (combo ~/ 4).clamp(0, 5);
  DashCreativeChallenge get challenge => challengeForRound(round);

  void restoreProgress({required int unlocked, required int completed}) {
    unlockedRound = math.max(1, unlocked);
    completedRounds = math.max(0, completed);
    round = unlockedRound;
  }

  void start({int? selectedRound}) {
    round = selectedRound ?? unlockedRound;
    state = MotionDashState.countdown;
    elapsed = 0;
    countdown = 3;
    score = combo = mistakes = passedObstacles = nextEventIndex = 0;
    lane = 1;
    cubeColor = CubeColor.blue;
    feedback = 'GET READY';
    feedbackTime = colorPulse = 0;
    events = _buildEvents(round);
  }

  void pause() {
    if (state == MotionDashState.running ||
        state == MotionDashState.countdown) {
      _pausedFrom = state;
      state = MotionDashState.paused;
    }
  }

  void resume() {
    if (state == MotionDashState.paused) state = _pausedFrom;
  }

  void moveLane(int direction) {
    if (state != MotionDashState.running) return;
    lane = (lane + direction).clamp(0, 2);
  }

  void tick(double dt) {
    if (state == MotionDashState.countdown) {
      countdown -= dt;
      if (countdown <= 0) {
        state = MotionDashState.running;
        feedback = 'RUN!';
        feedbackTime = .8;
      }
      return;
    }
    if (state != MotionDashState.running) return;
    elapsed += dt * speed;
    feedbackTime = math.max(0, feedbackTime - dt);
    colorPulse = math.max(0, colorPulse - dt);
    while (nextEvent != null && elapsed >= nextEvent!.time) {
      _resolve(nextEvent!);
      nextEventIndex++;
      if (state != MotionDashState.running) break;
    }
  }

  void _resolve(RunnerEvent event) {
    switch (event.type) {
      case RunnerEventType.colorGate:
        cubeColor = event.gateColor!;
        colorPulse = 1.0;
        feedback = 'COLOR SHIFT · ${cubeColor.label.toUpperCase()}';
        feedbackTime = 1.3;
        score += 35;
      case RunnerEventType.matchingBoxes:
        final matches = event.boxColors[lane] == cubeColor;
        if (matches) {
          passedObstacles++;
          combo++;
          score += (100 + (event.bonus ? 100 : 0)) * multiplier;
          feedback = event.bonus
              ? 'BONUS MATCH!  ×$multiplier'
              : 'COLOR MATCH!  ×$multiplier';
          feedbackTime = 1.0;
        } else {
          _mistake('WRONG COLOR');
        }
      case RunnerEventType.barrier:
        if (lane == event.blockedLane) {
          _mistake(event.moving ? 'SHIFTING BARRIER' : 'BARRIER HIT');
        } else {
          combo++;
          score += 45 * multiplier;
          feedback = 'CLEAR PATH  ×$multiplier';
          feedbackTime = .8;
        }
      case RunnerEventType.gap:
        if (lane != event.safeLane) {
          _mistake('MISSED SAFE PATH');
        } else {
          combo++;
          score += 80 * multiplier;
          feedback = 'SAFE PATH!  ×$multiplier';
          feedbackTime = .9;
        }
      case RunnerEventType.finish:
        state = MotionDashState.challenge;
        feedback = 'FINISH PORTAL';
        feedbackTime = 1.5;
    }
  }

  void _mistake(String message) {
    mistakes++;
    combo = 0;
    score = math.max(0, score - 35);
    feedback = message;
    feedbackTime = 1.0;
    if (mistakes >= 3) state = MotionDashState.gameOver;
  }

  /// Returns whether the answer was correct. Wrong answers can be retried.
  bool submitChallenge(int option) {
    if (state != MotionDashState.challenge) return false;
    if (option != challenge.answer) {
      feedback = 'Not quite · ${challenge.explanation}';
      feedbackTime = 2.5;
      return false;
    }
    score += 250;
    completedRounds = math.max(completedRounds, round);
    unlockedRound = math.max(unlockedRound, round + 1);
    state = MotionDashState.roundComplete;
    feedback = 'ROUND COMPLETE · +250';
    feedbackTime = 2.0;
    return true;
  }

  void startNextRound() => start(selectedRound: unlockedRound);

  List<RunnerEvent> _buildEvents(int roundNumber) {
    final pace = 1 / (1 + math.min(roundNumber - 1, 16) * .035);
    final data = <RunnerEvent>[];
    var activeColor = CubeColor.blue;
    var obstacleNumber = 0;
    final firstRing = _differentColor(
      CubeColor.values[(roundNumber + 1) % CubeColor.values.length],
      activeColor,
    );
    final ringColors = [
      firstRing,
      _differentColor(
        CubeColor.values[(roundNumber * 3 + 2) % CubeColor.values.length],
        firstRing,
      ),
    ];
    void obstacle(double time) {
      final correctLane = (obstacleNumber * 2 + roundNumber - 1) % 3;
      final colors = <CubeColor>[];
      var candidate =
          (roundNumber + obstacleNumber * 2) % CubeColor.values.length;
      for (var laneIndex = 0; laneIndex < 3; laneIndex++) {
        if (laneIndex == correctLane) {
          colors.add(activeColor);
        } else {
          while (CubeColor.values[candidate] == activeColor ||
              colors.contains(CubeColor.values[candidate])) {
            candidate = (candidate + 1) % CubeColor.values.length;
          }
          colors.add(CubeColor.values[candidate]);
          candidate = (candidate + 1) % CubeColor.values.length;
        }
      }
      data.add(RunnerEvent(
        time: time * pace,
        type: RunnerEventType.matchingBoxes,
        boxColors: List.unmodifiable(colors),
        requiredColor: activeColor,
        bonus: roundNumber >= 5 && obstacleNumber.isEven,
      ));
      obstacleNumber++;
    }

    obstacle(4.0);
    data.add(RunnerEvent(
        time: 6.2 * pace,
        type: RunnerEventType.colorGate,
        gateColor: ringColors[0]));
    activeColor = ringColors[0];
    obstacle(8.4);
    final movingBarrier = roundNumber >= 4;
    data.add(RunnerEvent(
        time: 10.6 * pace,
        type: RunnerEventType.barrier,
        blockedLane: (roundNumber + 1) % 3,
        moving: movingBarrier));
    if (roundNumber >= 5) {
      data.add(RunnerEvent(
        time: 12.7 * pace,
        type: RunnerEventType.gap,
        safeLane: (roundNumber * 2) % 3,
      ));
      obstacle(14.9);
      data.add(RunnerEvent(
          time: 17.1 * pace,
          type: RunnerEventType.colorGate,
          gateColor: ringColors[1]));
      activeColor = ringColors[1];
      obstacle(19.3);
      data.add(RunnerEvent(time: 21.5 * pace, type: RunnerEventType.finish));
    } else {
      obstacle(12.7);
      data.add(RunnerEvent(
          time: 14.9 * pace,
          type: RunnerEventType.colorGate,
          gateColor: ringColors[1]));
      activeColor = ringColors[1];
      obstacle(17.1);
      data.add(RunnerEvent(time: 19.3 * pace, type: RunnerEventType.finish));
    }
    return List.unmodifiable(data);
  }

  CubeColor _differentColor(CubeColor candidate, CubeColor avoid) =>
      candidate == avoid
          ? CubeColor.values[(candidate.index + 1) % CubeColor.values.length]
          : candidate;

  static DashCreativeChallenge challengeForRound(int round) {
    final variant = (round - 1) ~/ 6;
    final brand =
        ['ION PULSE', 'MOSS & MOON', 'ASTER OBJECTS', 'NORTHSTAR'][variant % 4];
    final templates = <DashCreativeChallenge>[
      DashCreativeChallenge(
          category: 'BEST COLOR COMBINATION',
          brief: '$brand · futuristic product launch',
          question:
              'Which palette best fits a confident, premium technology product?',
          options: const [
            DashChallengeOption(
                title: 'Electric blue + violet',
                detail: 'High energy, clear tech feel',
                colors: [CubeColor.blue, CubeColor.violet]),
            DashChallengeOption(
                title: 'Sage + warm cream',
                detail: 'Quiet, natural and soft',
                colors: [CubeColor.green, CubeColor.yellow]),
            DashChallengeOption(
                title: 'Red + orange',
                detail: 'Hot, urgent and loud',
                colors: [CubeColor.red, CubeColor.orange]),
          ],
          answer: 0,
          explanation:
              'Electric blue and violet support a polished futuristic technology mood.'),
      DashCreativeChallenge(
          category: 'TYPOGRAPHY',
          brief: '$brand · mobile campaign headline',
          question:
              'Which pairing gives a premium headline personality while keeping details easy to read?',
          options: const [
            DashChallengeOption(
                title: 'Geometric display + neutral sans',
                detail: 'Distinct heading, calm body copy',
                typeSample: 'Aa  /  Aa'),
            DashChallengeOption(
                title: 'Three decorative display faces',
                detail: 'Competing voices at every size',
                typeSample: 'Aa  Aa  Aa'),
            DashChallengeOption(
                title: 'Thin script for every line',
                detail: 'Low clarity at small sizes',
                typeSample: 'Aa  Aa'),
          ],
          answer: 0,
          explanation:
              'A distinctive heading with a restrained, readable body face creates hierarchy.'),
      DashCreativeChallenge(
          category: 'GRADIENT & CONTRAST',
          brief: '$brand · interface hero panel',
          question:
              'Which treatment keeps a white call-to-action readable over a dark hero?',
          options: const [
            DashChallengeOption(
                title: 'Deep navy → violet',
                detail: 'Strong contrast beneath white text',
                colors: [CubeColor.blue, CubeColor.violet]),
            DashChallengeOption(
                title: 'Pale cyan → white',
                detail: 'Very little text contrast',
                colors: [CubeColor.cyan, CubeColor.yellow]),
            DashChallengeOption(
                title: 'Bright yellow → white',
                detail: 'Similar lightness values',
                colors: [CubeColor.yellow, CubeColor.orange]),
          ],
          answer: 0,
          explanation:
              'A darker gradient creates enough luminance contrast for white type.'),
      DashCreativeChallenge(
          category: 'GRAPHIC DESIGN',
          brief: '$brand · square social poster',
          question: 'Which composition will be easiest to scan on a phone?',
          options: const [
            DashChallengeOption(
                title: 'One headline, one focal image',
                detail: 'Clear hierarchy and generous margins'),
            DashChallengeOption(
                title: 'Equal-sized copy in every corner',
                detail: 'No visual entry point'),
            DashChallengeOption(
                title: 'Text placed over the busiest area',
                detail: 'Poor separation and readability'),
          ],
          answer: 0,
          explanation:
              'One clear headline and a single focal point establish a quick reading order.'),
      DashCreativeChallenge(
          category: 'MOTION DESIGN',
          brief: '$brand · short product reveal',
          question:
              'Which timing makes a title land with a polished, controlled feel?',
          options: const [
            DashChallengeOption(
                title: 'Ease out into a short settle',
                detail: 'Decelerates into its final position'),
            DashChallengeOption(
                title: 'Stop instantly at full speed',
                detail: 'Abrupt and difficult to follow'),
            DashChallengeOption(
                title: 'Overshoot repeatedly',
                detail: 'Adds motion without a reason'),
          ],
          answer: 0,
          explanation:
              'An ease-out and brief settle give the movement a clear, intentional finish.'),
      DashCreativeChallenge(
          category: 'CREATIVE 3D',
          brief: '$brand · hero object render',
          question:
              'Which lighting setup reveals a product silhouette while keeping material detail?',
          options: const [
            DashChallengeOption(
                title: 'Key + soft fill + rim',
                detail: 'Shape, shadow control and separation'),
            DashChallengeOption(
                title: 'Equal flat light everywhere',
                detail: 'Little shape or depth'),
            DashChallengeOption(
                title: 'Only a hard backlight',
                detail: 'Silhouette detail disappears'),
          ],
          answer: 0,
          explanation:
              'A key defines the form, fill controls shadows, and a subtle rim separates the subject.'),
    ];
    final base = templates[(round - 1) % templates.length];
    if (variant == 0) return base;
    final shift = variant % base.options.length;
    final rotated = List.generate(base.options.length,
        (index) => base.options[(index + shift) % base.options.length]);
    final answer =
        (base.answer - shift + base.options.length) % base.options.length;
    return DashCreativeChallenge(
      category: base.category,
      brief: '$brand · creative brief ${round.toString().padLeft(2, '0')}',
      question: '$brand · round $round: ${base.question}',
      options: rotated,
      answer: answer,
      explanation: base.explanation,
    );
  }
}

extension CubeColorStyle on CubeColor {
  String get label => switch (this) {
        CubeColor.blue => 'Blue',
        CubeColor.violet => 'Violet',
        CubeColor.cyan => 'Cyan',
        CubeColor.green => 'Green',
        CubeColor.yellow => 'Yellow',
        CubeColor.orange => 'Orange',
        CubeColor.magenta => 'Magenta',
        CubeColor.red => 'Red',
      };
}
