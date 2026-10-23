import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/idea_music_track.dart';
import 'edge_function_errors.dart';
import 'idea_lab_backend.dart';

abstract interface class IdeaMusicSearchGateway {
  Future<IdeaMusicSearchPage> search({required String query, required String category, int page = 1});
  Future<List<IdeaMusicTrack>> related(IdeaMusicTrack track);
}

class IdeaMusicSearchPage {
  const IdeaMusicSearchPage({required this.tracks, required this.hasMore});
  final List<IdeaMusicTrack> tracks;
  final bool hasMore;
}

class SupabaseIdeaMusicSearchGateway implements IdeaMusicSearchGateway {
  @override
  Future<IdeaMusicSearchPage> search({required String query, required String category, int page = 1}) async {
    final data = await _invoke({'action': 'search', 'query': query, 'category': category, 'page': page});
    final rows = data['tracks'];
    if (rows is! List) throw StateError('Music search returned an invalid response.');
    final hasMore = data['hasMore'] == true;
    return IdeaMusicSearchPage(tracks: _parseTracks(rows), hasMore: hasMore);
  }

  @override
  Future<List<IdeaMusicTrack>> related(IdeaMusicTrack track) async {
    final data = await _invoke({
      'action': 'related',
      'track': {
        'id': track.id,
        'title': track.title,
        'creator': track.creator,
        'genres': track.genres,
        'tags': track.tags,
        'category': track.category,
      },
    });
    final rows = data['tracks'];
    return rows is List ? _parseTracks(rows) : const [];
  }

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> body) async {
    if (!IdeaLabBackend.isReady || IdeaLabBackend.currentUser == null) {
      throw StateError('Sign in to search the music library.');
    }
    late final FunctionResponse result;
    try {
      result = await IdeaLabBackend.client.functions.invoke(
        'idea-music-search',
        body: body,
      );
    } on FunctionException catch (error) {
      throw StateError(
        EdgeFunctionErrors.friendlyMessage(
          error.details,
          fallback: 'The music catalogue is temporarily unavailable.',
          status: error.status,
        ),
      );
    }
    if (result.status < 200 || result.status >= 300) {
      throw StateError(
        EdgeFunctionErrors.friendlyMessage(
          result.data,
          fallback: 'The music catalogue is temporarily unavailable.',
          status: result.status,
        ),
      );
    }
    if (result.data is! Map<String, dynamic>) throw StateError('Music service returned an invalid response.');
    return result.data as Map<String, dynamic>;
  }

  List<IdeaMusicTrack> _parseTracks(List<dynamic> rows) {
    final tracks = <IdeaMusicTrack>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final track = tryParseTrack(row);
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  static IdeaMusicTrack? tryParseTrack(Map<String, dynamic> row) {
    try {
      return IdeaMusicTrack.fromJson(row);
    } on FormatException {
      return null;
    }
  }
}

class IdeaMusicCatalog {
  IdeaMusicCatalog({IdeaMusicSearchGateway? gateway})
      : _gateway = gateway ?? SupabaseIdeaMusicSearchGateway();
  final IdeaMusicSearchGateway _gateway;
  static const _cacheDuration = Duration(minutes: 5);
  final Map<String, ({DateTime savedAt, IdeaMusicSearchPage page})> _searchCache = {};
  final Map<String, ({DateTime savedAt, List<IdeaMusicTrack> tracks})> _relatedCache = {};

  Future<IdeaMusicSearchPage> search({required String query, required String category, int page = 1}) async {
    final key = '${category.toLowerCase()}|${query.trim().toLowerCase()}|$page';
    final cached = _searchCache[key];
    if (cached != null && DateTime.now().difference(cached.savedAt) < _cacheDuration) return cached.page;
    final result = await _gateway.search(query: query.trim(), category: category, page: page);
    final tracks = result.tracks.where(_hasUsableLicenseAndUrls)
      .fold<Map<String, IdeaMusicTrack>>({}, (unique, track) {
        unique.putIfAbsent(track.id, () => track);
        return unique;
      }).values.toList(growable: false);
    final filtered = IdeaMusicSearchPage(tracks: tracks, hasMore: result.hasMore);
    _searchCache[key] = (savedAt: DateTime.now(), page: filtered);
    return filtered;
  }

  Future<List<IdeaMusicTrack>> related(IdeaMusicTrack track) async {
    final cached = _relatedCache[track.id];
    if (cached != null && DateTime.now().difference(cached.savedAt) < _cacheDuration) return cached.tracks;
    final results = await _gateway.related(track);
    final related = results.where((candidate) =>
        candidate.id != track.id &&
        _hasUsableLicenseAndUrls(candidate))
      .fold<Map<String, IdeaMusicTrack>>({}, (unique, candidate) {
        unique.putIfAbsent(candidate.id, () => candidate);
        return unique;
      }).values.toList(growable: false);
    _relatedCache[track.id] = (savedAt: DateTime.now(), tracks: related);
    return related;
  }

  bool _hasUsableLicenseAndUrls(IdeaMusicTrack track) =>
      (IdeaMusicTrack.licenseAllowsCommercialAdaptation(track.licenseCode) ||
          (track.provider == 'Original' && track.licenseCode == 'original')) &&
      track.audioUrl.startsWith('https://') &&
      track.sourceUrl.startsWith('https://') &&
      (track.provider == 'Original' || track.licenseUrl.startsWith('https://'));
}
