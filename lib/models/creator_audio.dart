class CreatorAudio {
  const CreatorAudio({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.genre,
    required this.description,
    required this.audioPath,
    required this.coverPath,
    required this.durationSeconds,
    required this.status,
    required this.plays,
    required this.likes,
    this.audioSignedUrl,
    this.coverSignedUrl,
  });

  final String id;
  final String ownerId;
  final String title;
  final String genre;
  final String description;
  final String audioPath;
  final String? coverPath;
  final int durationSeconds;
  final String status;
  final int plays;
  final int likes;
  final String? audioSignedUrl;
  final String? coverSignedUrl;

  factory CreatorAudio.fromRow(Map<String, dynamic> row) => CreatorAudio(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        title: row['title'] as String,
        genre: row['genre'] as String? ?? '',
        description: row['description'] as String? ?? '',
        audioPath: row['audio_url'] as String,
        coverPath: row['cover_url'] as String?,
        durationSeconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
        status: row['status'] as String? ?? 'pending',
        plays: (row['plays_count'] as num?)?.toInt() ?? 0,
        likes: (row['likes_count'] as num?)?.toInt() ?? 0,
      );

  CreatorAudio withSignedUrls({String? audio, String? cover}) => CreatorAudio(
        id: id,
        ownerId: ownerId,
        title: title,
        genre: genre,
        description: description,
        audioPath: audioPath,
        coverPath: coverPath,
        durationSeconds: durationSeconds,
        status: status,
        plays: plays,
        likes: likes,
        audioSignedUrl: audio,
        coverSignedUrl: cover,
      );

  String get statusLabel => switch (status) {
        'approved' => 'Approved',
        'hidden' => 'Hidden',
        'removed' => 'Removed',
        _ => 'Pending',
      };
}
