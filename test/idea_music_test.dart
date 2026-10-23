import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/idea_music_track.dart';
import 'package:my_first_app/screens/idea_lab/idea_music_library_screen.dart';
import 'package:my_first_app/services/idea_music_catalog.dart';

class _MusicGateway implements IdeaMusicSearchGateway {
  _MusicGateway({this.failure, this.hasMore = false});
  Object? failure;
  bool hasMore;
  String? lastQuery;
  String? lastCategory;
  int? lastPage;
  int searchCalls = 0;
  int relatedCalls = 0;

  @override
  Future<IdeaMusicSearchPage> search({required String query, required String category, int page = 1}) async {
    searchCalls++;
    lastQuery = query;
    lastCategory = category;
    lastPage = page;
    if (failure case final error?) throw error;
    return IdeaMusicSearchPage(tracks: [
      const IdeaMusicTrack(
        id: 'openverse-1',
        title: 'Sample open track',
        creator: 'Artist',
        duration: Duration(seconds: 60),
        audioUrl: 'https://example.org/audio.mp3',
        sourceUrl: 'https://example.org/source',
        license: 'CC BY 4.0',
        licenseCode: 'by',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        attribution: 'Credit Artist',
      ),
      const IdeaMusicTrack(
        id: 'bad-license',
        title: 'Noncommercial track',
        creator: 'Artist',
        duration: Duration(seconds: 60),
        audioUrl: 'https://example.org/audio.mp3',
        sourceUrl: 'https://example.org/source',
        license: 'CC BY-NC 4.0',
        licenseCode: 'by-nc',
        licenseUrl: 'https://creativecommons.org/licenses/by-nc/4.0/',
        attribution: 'Credit Artist',
      ),
    ], hasMore: hasMore);
  }

  @override
  Future<List<IdeaMusicTrack>> related(IdeaMusicTrack track) async {
    relatedCalls++;
    return [
      const IdeaMusicTrack(
        id: 'openverse-related', title: 'Related instrumental', creator: 'Artist',
        duration: Duration(seconds: 90), audioUrl: 'https://example.org/related.mp3',
        sourceUrl: 'https://example.org/related', license: 'CC BY 4.0', licenseCode: 'by',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/', attribution: 'Credit Artist',
      ),
      const IdeaMusicTrack(
        id: 'duplicate-or-invalid', title: 'Invalid licensed audio', creator: 'Artist',
        duration: Duration(seconds: 90), audioUrl: 'https://example.org/no.mp3',
        sourceUrl: 'https://example.org/no', license: 'NC', licenseCode: 'by-nc',
        licenseUrl: 'https://creativecommons.org/licenses/by-nc/4.0/', attribution: '',
      ),
    ];
  }
}

void main() {
  test('track parser rejects noncommercial and no-derivatives licenses', () {
    expect(IdeaMusicTrack.licenseAllowsCommercialAdaptation('cc0'), isTrue);
    expect(IdeaMusicTrack.licenseAllowsCommercialAdaptation('pdm'), isTrue);
    expect(IdeaMusicTrack.licenseAllowsCommercialAdaptation('by'), isTrue);
    for (final license in ['by-nc', 'by-nd', 'by-sa', 'sampling+']) {
      expect(IdeaMusicTrack.licenseAllowsCommercialAdaptation(license), isFalse);
    }
  });

  test('catalog retains required metadata and filters disallowed licenses', () async {
    final gateway = _MusicGateway();
    final tracks = await IdeaMusicCatalog(gateway: gateway).search(query: 'ambient', category: 'popular');
    expect(gateway.lastQuery, 'ambient');
    expect(gateway.lastCategory, 'popular');
    expect(gateway.lastPage, 1);
    expect(tracks.tracks.map((track) => track.id), ['openverse-1']);
    expect(tracks.tracks.single.toJson()['license_url'], contains('creativecommons.org'));
  });

  test('catalog keeps pagination state so more real results can be requested', () async {
    final gateway = _MusicGateway(hasMore: true);
    final page = await IdeaMusicCatalog(gateway: gateway).search(
      query: 'Hindi music',
      category: 'indian',
      page: 2,
    );
    expect(gateway.lastQuery, 'Hindi music');
    expect(gateway.lastCategory, 'indian');
    expect(gateway.lastPage, 2);
    expect(page.hasMore, isTrue);
  });

  test('catalog caches pages and related tracks and filters related licences', () async {
    final gateway = _MusicGateway();
    final catalog = IdeaMusicCatalog(gateway: gateway);
    const selected = IdeaMusicTrack(
      id: 'openverse-1', title: 'Indian cinematic instrumental', creator: 'Artist',
      duration: Duration(seconds: 60), audioUrl: 'https://example.org/audio.mp3',
      sourceUrl: 'https://example.org/source', license: 'CC BY 4.0', licenseCode: 'by',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/', attribution: 'Credit Artist',
      tags: ['cinematic', 'Indian'], genres: ['instrumental'],
    );
    await catalog.search(query: 'Indian instrumental', category: 'indian_instrumental');
    await catalog.search(query: 'Indian instrumental', category: 'indian_instrumental');
    expect(gateway.searchCalls, 1);
    final first = await catalog.related(selected);
    final second = await catalog.related(selected);
    expect(first.map((item) => item.id), ['openverse-related']);
    expect(second, first);
    expect(gateway.relatedCalls, 1);
  });

  test('selected music segment round trips for post and story metadata', () {
    const selection = IdeaMusicSelection(
      track: IdeaMusicTrack(
        id: 'track-42',
        title: 'Atmosphere',
        creator: 'Artist',
        duration: Duration(minutes: 3),
        audioUrl: 'https://example.org/audio.mp3',
        sourceUrl: 'https://example.org/source',
        license: 'CC BY 4.0',
        licenseCode: 'by',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        attribution: 'Artist — Atmosphere',
      ),
      start: Duration(seconds: 17),
      end: Duration(seconds: 28),
      volume: 0.6,
    );
    final restored = IdeaMusicSelection.fromJson(selection.toJson());
    expect(restored.track.id, 'track-42');
    expect(restored.track.licenseCode, 'by');
    expect(restored.start, const Duration(seconds: 17));
    expect(restored.end, const Duration(seconds: 28));
    expect(restored.volume, 0.6);
  });

  testWidgets('music library displays retry when search fails', (tester) async {
    final gateway = _MusicGateway(failure: StateError('Catalogue unavailable'));
    await tester.pumpWidget(MaterialApp(home: IdeaMusicLibraryScreen(catalog: IdeaMusicCatalog(gateway: gateway))));
    await tester.pumpAndSettle();
    expect(find.text('Could not load music'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(gateway.lastCategory, 'popular');
  });

  testWidgets('music library offers categories and empty search state', (tester) async {
    final gateway = _MusicGateway();
    await tester.pumpWidget(MaterialApp(home: IdeaMusicLibraryScreen(catalog: IdeaMusicCatalog(gateway: gateway))));
    await tester.pumpAndSettle();
    expect(find.text('Popular / Featured'), findsOneWidget);
    expect(find.text('Indian Instrumental'), findsOneWidget);
    expect(find.text('Cinematic'), findsOneWidget);
    expect(find.text('Emotional'), findsOneWidget);
    expect(find.text('Sound Effects'), findsOneWidget);
    expect(find.text('sad piano'), findsOneWidget);
    expect(find.text('Indian'), findsOneWidget);
    expect(find.text('Hindi / Bollywood'), findsOneWidget);
    expect(find.text('Tamil'), findsOneWidget);
    expect(find.text('Sound Effects'), findsOneWidget);
    expect(find.textContaining('does not provide a live trending chart'), findsOneWidget);
    expect(find.text('Sample open track'), findsOneWidget);
  });
}
