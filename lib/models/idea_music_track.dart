/// An Openverse audio result. Licence metadata is retained so creators can
/// review the original source and comply with its attribution terms.
class IdeaMusicTrack {
  const IdeaMusicTrack({
    required this.id,
    required this.title,
    required this.creator,
    required this.duration,
    required this.audioUrl,
    required this.sourceUrl,
    required this.license,
    this.licenseCode = '',
    required this.licenseUrl,
    required this.attribution,
    this.artworkUrl,
    this.creatorUrl,
    this.tags = const [],
    this.genres = const [],
    this.category = 'music',
    this.provider = 'Openverse',
    this.audioId,
  });

  final String id;
  final String title;
  final String creator;
  final Duration duration;
  final String audioUrl;
  final String sourceUrl;
  final String license;
  final String licenseCode;
  final String licenseUrl;
  final String attribution;
  final String? artworkUrl;
  final String? creatorUrl;
  final List<String> tags;
  final List<String> genres;
  final String category;
  final String provider;
  final String? audioId;

  static const permittedLicenses = {'cc0', 'pdm', 'by'};

  static bool licenseAllowsCommercialAdaptation(String value) =>
      permittedLicenses.contains(value.toLowerCase().trim());

  factory IdeaMusicTrack.fromJson(Map<String, dynamic> json) {
    final license = (json['license'] as String? ?? '').toLowerCase().trim();
    final provider = json['provider'] as String? ?? 'Openverse';
    if (!licenseAllowsCommercialAdaptation(license)) {
      throw const FormatException('This track licence is not enabled for use.');
    }
    final audio = Uri.tryParse(json['url'] as String? ?? '');
    final source = Uri.tryParse(json['foreign_landing_url'] as String? ?? '');
    final licenseUri = Uri.tryParse(json['license_url'] as String? ?? '');
    if (audio?.scheme != 'https' || source?.scheme != 'https' || licenseUri?.scheme != 'https') {
      throw const FormatException('The track has incomplete source or licence details.');
    }
    return IdeaMusicTrack(
      id: json['id'] as String,
      title: (json['title'] as String? ?? '').trim().isEmpty
          ? 'Untitled audio'
          : (json['title'] as String).trim(),
      creator: (json['creator'] as String? ?? '').trim().isEmpty
          ? 'Unknown creator'
          : (json['creator'] as String).trim(),
      duration: Duration(milliseconds: (json['duration'] as num?)?.round() ?? 0),
      audioUrl: audio.toString(),
      sourceUrl: source.toString(),
      license: _licenseLabel(license, json['license_version'] as String?),
      licenseCode: license,
      licenseUrl: licenseUri.toString(),
      attribution: (json['attribution'] as String? ?? '').trim(),
      artworkUrl: _httpsUrl(json['thumbnail'] as String?),
      creatorUrl: _httpsUrl(json['creator_url'] as String?),
      tags: _stringList(json['tags']),
      genres: _stringList(json['genres']),
      category: json['category'] as String? ?? 'music',
      provider: provider,
      audioId: json['audio_id'] as String?,
    );
  }

  Map<String, dynamic> toJson({Duration? start, Duration? end}) => {
        'provider': provider,
        if (audioId != null) 'audio_id': audioId,
        'track_id': id,
        'title': title,
        'creator': creator,
        'duration_ms': duration.inMilliseconds,
        'audio_url': audioUrl,
        'artwork_url': artworkUrl,
        'source_url': sourceUrl,
        'license': license,
        'license_code': licenseCode,
        'license_url': licenseUrl,
        'attribution': attribution,
        'creator_url': creatorUrl,
        'tags': tags,
        'genres': genres,
        'category': category,
        'segment_start_ms': (start ?? Duration.zero).inMilliseconds,
        'segment_end_ms': (end ?? duration).inMilliseconds,
      };

  static String? _httpsUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');
    return uri?.scheme == 'https' ? uri.toString() : null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item is Map ? item['name'] : item)
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _licenseLabel(String code, String? version) {
    final name = switch (code) {
      'cc0' => 'CC0',
      'pdm' => 'Public Domain Mark',
      'by' => 'CC BY',
      _ => code.toUpperCase(),
    };
    return [name, if (version != null && version.isNotEmpty) version].join(' ');
  }
}

class IdeaMusicSelection {
  const IdeaMusicSelection({
    required this.track,
    required this.start,
    required this.end,
    this.volume = 0.25,
  });

  final IdeaMusicTrack track;
  final Duration start;
  final Duration end;
  final double volume;

  Map<String, dynamic> toJson() => {
        ...track.toJson(start: start, end: end),
        'volume': volume.clamp(0.0, 1.0),
      };

  factory IdeaMusicSelection.fromJson(Map<String, dynamic> json) {
    final track = IdeaMusicTrack(
      id: json['track_id'] as String,
      title: json['title'] as String? ?? 'Untitled audio',
      creator: json['creator'] as String? ?? 'Unknown creator',
      duration: Duration(milliseconds: (json['duration_ms'] as num?)?.toInt() ?? 0),
      audioUrl: json['audio_url'] as String,
      sourceUrl: json['source_url'] as String,
      license: json['license'] as String,
      licenseCode: json['license_code'] as String? ?? '',
      licenseUrl: json['license_url'] as String? ?? '',
      attribution: json['attribution'] as String? ?? '',
      artworkUrl: json['artwork_url'] as String?,
      creatorUrl: json['creator_url'] as String?,
      tags: IdeaMusicTrack._stringList(json['tags']),
      genres: IdeaMusicTrack._stringList(json['genres']),
      category: json['category'] as String? ?? 'music',
      provider: json['provider'] as String? ?? 'Openverse',
      audioId: json['audio_id'] as String?,
    );
    return IdeaMusicSelection(
      track: track,
      start: Duration(milliseconds: (json['segment_start_ms'] as num?)?.toInt() ?? 0),
      end: Duration(milliseconds: (json['segment_end_ms'] as num?)?.toInt() ?? track.duration.inMilliseconds),
      volume: ((json['volume'] as num?)?.toDouble() ?? 0.25).clamp(0.0, 1.0).toDouble(),
    );
  }
}
