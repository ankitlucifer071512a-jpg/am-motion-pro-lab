import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/creator_audio.dart';
import 'package:my_first_app/services/creator_music_service.dart';

void main() {
  test('audio status labels reflect moderation states', () {
    final base = <String, dynamic>{
      'id': 'audio-id',
      'owner_id': 'owner-id',
      'title': 'Track',
      'audio_url': 'owner-id/audio-id/track.mp3',
      'duration_seconds': 0,
      'plays_count': 0,
      'likes_count': 0,
    };

    expect(CreatorAudio.fromRow({...base, 'status': 'pending'}).statusLabel, 'Pending');
    expect(CreatorAudio.fromRow({...base, 'status': 'approved'}).statusLabel, 'Approved');
    expect(CreatorAudio.fromRow({...base, 'status': 'hidden'}).statusLabel, 'Hidden');
    expect(CreatorAudio.fromRow({...base, 'status': 'removed'}).statusLabel, 'Removed');
  });

  test('m4a upload MIME is normalized to the bucket supported type', () {
    expect(CreatorMusicService.audioContentType('track.mp3'), 'audio/mpeg');
    expect(CreatorMusicService.audioContentType('track.m4a'), 'audio/mp4');
  });
}
