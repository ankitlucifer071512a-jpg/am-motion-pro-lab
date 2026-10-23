import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/idea_lab_idea.dart';
import 'package:my_first_app/screens/idea_lab/idea_lab_screen.dart';
import 'package:my_first_app/services/idea_bookmark_store.dart';
import 'package:my_first_app/services/idea_lab_repository.dart';
import 'package:my_first_app/widgets/bottom_nav.dart';
import 'package:my_first_app/widgets/idea_lab_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('idea catalogue has distinct, complete, filterable entries', () {
    const ideas = IdeaLabRepository.ideas;
    expect(ideas.length, greaterThanOrEqualTo(12));
    expect(ideas.map((idea) => idea.id).toSet(), hasLength(ideas.length));
    expect(ideas.map((idea) => idea.title).toSet(), hasLength(ideas.length));

    for (final category in IdeaLabRepository.categories.skip(1)) {
      expect(
        ideas.where((idea) => idea.matchesCategory(category)),
        isNotEmpty,
        reason: category,
      );
    }
    for (final idea in ideas) {
      expect(idea.description, isNotEmpty, reason: idea.id);
      expect(idea.learningObjective, isNotEmpty, reason: idea.id);
      expect(idea.software, isNotEmpty, reason: idea.id);
      expect(idea.requiredAssets, isNotEmpty, reason: idea.id);
      expect(idea.tutorialSteps, isNotEmpty, reason: idea.id);
      expect(idea.assignment, isNotEmpty, reason: idea.id);
      expect(idea.checklist, isNotEmpty, reason: idea.id);
      expect(
        idea.relatedIdeaIds.every(
          (id) => ideas.any((candidate) => candidate.id == id),
        ),
        isTrue,
        reason: idea.id,
      );
    }
    expect(
      ideas.where((idea) => idea.matchesSearch('planar')).single.id,
      'screen-replacement-vfx',
    );
    expect(
      IdeaLabRepository.byId('3d-product-lighting').tutorialSteps.first,
      contains('camera'),
    );
  });

  test('bookmarks persist locally and toggle independently', () async {
    final store = IdeaBookmarkStore.instance;
    expect(await store.savedIds, isEmpty);

    expect(await store.toggle('cinematic-product-reveal'),
        {'cinematic-product-reveal'});
    expect(await store.savedIds, {'cinematic-product-reveal'});

    expect(await store.toggle('cinematic-product-reveal'), isEmpty);
    expect(await store.savedIds, isEmpty);
  });

  testWidgets('search, category filters, and reset update idea cards',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IdeaLabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(IdeaLabCard),
      findsNWidgets(IdeaLabRepository.ideas.length - 1),
    );
    await tester.enterText(
      find.byType(TextField),
      'planar',
    );
    await tester.pumpAndSettle();
    expect(find.byType(IdeaLabCard), findsOneWidget);

    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(-900, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '3D Animation'));
    await tester.pumpAndSettle();
    expect(find.byType(IdeaLabCard), findsNWidgets(3));
    expect(find.text('3D Product Lighting Setup'), findsOneWidget);
  });

  testWidgets('idea opens its relevant written practice task', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IdeaLabScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('3D Product Lighting Setup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3D Product Lighting Setup'));
    await tester.pumpAndSettle();

    expect(find.text('Tutorial steps'), findsOneWidget);
    expect(find.textContaining('Place a large key light'), findsOneWidget);
    await tester.ensureVisible(find.text('Start Practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR PRACTICE BRIEF'), findsOneWidget);
    expect(find.textContaining('Render the same product'), findsOneWidget);
    expect(find.text('Review your result'), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('saved ideas filter shows the persisted bookmark',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IdeaLabScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save idea').first);
    await tester.pumpAndSettle();
    expect(
      await IdeaBookmarkStore.instance.savedIds,
      contains('cinematic-product-reveal'),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Saved ideas'));
    await tester.pumpAndSettle();

    expect(find.byType(IdeaLabCard), findsOneWidget);
    expect(find.text('Cinematic Product Reveal'), findsOneWidget);
  });

  testWidgets('Idea Lab has its own navigation destination', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AmBottomNav(
            index: 0,
            onChanged: (index) => selected = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Idea Lab'));
    expect(selected, 3);
  });

  testWidgets('all bottom tabs remain accessible and ordered on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const labels = [
      'Home',
      'Courses',
      'Game Lab',
      'Idea Lab',
      'Purchase Courses',
      'Notifications',
      'Profile',
    ];
    expect(AmBottomNav.items.map((item) => item.label), labels);

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: AmBottomNav(
              index: selected,
              onChanged: (index) => setState(() => selected = index),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigation = find.byType(AmBottomNav);
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      final item = find.descendant(of: navigation, matching: find.text(label));
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(selected, i, reason: label);
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('Idea Lab renders at a narrow mobile width without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IdeaLabScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(IdeaLabCard), findsWidgets);
  });

  test('idea categories can be queried without mutating the catalog', () {
    const idea = IdeaLabIdea(
      id: 'sample',
      title: 'Sample',
      description: 'A matching description',
      learningObjective: 'Practice matching',
      category: 'Graphic Design',
      tags: ['beginner tutorials'],
      difficulty: 'Intermediate',
      practiceMinutes: null,
      imageAsset: null,
      software: [],
      requiredAssets: [],
      tutorialSteps: [],
      assignment: 'Make a study',
      checklist: [],
      relatedIdeaIds: [],
    );
    expect(idea.matchesCategory('Beginner Tutorials'), isTrue);
    expect(idea.matchesSearch('matching'), isTrue);
    expect(idea.durationLabel, isEmpty);
  });
}
