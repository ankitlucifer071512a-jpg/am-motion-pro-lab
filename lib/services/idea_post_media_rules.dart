enum IdeaPostMediaKind { photos, video, invalid }

class IdeaPostMediaSelection {
  const IdeaPostMediaSelection({
    required this.kind,
    required this.files,
    this.error,
  });

  final IdeaPostMediaKind kind;
  final List<String> files;
  final String? error;
}

class IdeaPostMediaRules {
  IdeaPostMediaRules._();

  static const maxPhotoBytes = 50 * 1024 * 1024;
  static const maxVideoBytes = 150 * 1024 * 1024;
  static const maxVideoDuration = Duration(minutes: 2);

  static IdeaPostMediaSelection classify(Iterable<String> filenames) {
    final photos = <String>[];
    final videos = <String>[];
    final unsupported = <String>[];
    for (final filename in filenames) {
      final extension = filename.split('.').last.toLowerCase();
      if (const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        photos.add(filename);
      } else if (extension == 'mp4') {
        videos.add(filename);
      } else {
        unsupported.add(filename);
      }
    }
    if (unsupported.isNotEmpty) {
      return const IdeaPostMediaSelection(
        kind: IdeaPostMediaKind.invalid,
        files: [],
        error: 'Choose JPG, PNG, or WebP photos, or MP4 video.',
      );
    }
    if (photos.isNotEmpty && videos.isNotEmpty) {
      return const IdeaPostMediaSelection(
        kind: IdeaPostMediaKind.invalid,
        files: [],
        error: 'Choose photos or a video in one selection.',
      );
    }
    if (videos.length > 1) {
      return const IdeaPostMediaSelection(
        kind: IdeaPostMediaKind.invalid,
        files: [],
        error: 'Choose one MP4 video per post.',
      );
    }
    if (photos.isNotEmpty) {
      return IdeaPostMediaSelection(
        kind: IdeaPostMediaKind.photos,
        files: photos,
      );
    }
    if (videos.length == 1) {
      return IdeaPostMediaSelection(
        kind: IdeaPostMediaKind.video,
        files: videos,
      );
    }
    return const IdeaPostMediaSelection(
      kind: IdeaPostMediaKind.invalid,
      files: [],
      error: 'Choose at least one photo or one MP4 video.',
    );
  }

  static String? videoError({
    required int width,
    required int height,
    required Duration duration,
    required int sizeBytes,
  }) {
    if (sizeBytes <= 0 || sizeBytes > maxVideoBytes) {
      return 'Video must be a valid MP4 no larger than 150 MiB.';
    }
    if (width <= 0 || height <= 0) {
      return 'Could not read the video dimensions. Export an H.264 MP4 and try again.';
    }
    if (duration <= Duration.zero) {
      return 'Could not read the video duration. Export an H.264 MP4 and try again.';
    }
    if (duration > maxVideoDuration) {
      return 'This video is longer than 2 minutes. Trim it and choose it again.';
    }
    final ratio = width / height;
    if (ratio < .5 || ratio > 2.4) {
      return 'Video ratio must be between 1:2 and 2.4:1.';
    }
    return null;
  }

  static String videoBadge(int width, int height) {
    final ratio = width / height;
    if (ratio >= .9 && ratio <= 1.1) return 'Square';
    if (ratio < 1) return 'Reel 9:16';
    return 'Video 16:9';
  }
}
