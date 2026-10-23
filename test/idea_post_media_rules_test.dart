import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/idea_post_media_rules.dart';

void main() {
  group('IdeaPostMediaRules', () {
    test(
      'accepts portrait, landscape, and square videos up to two minutes',
      () {
        for (final size in const [(720, 1280), (1920, 1080), (1080, 1080)]) {
          expect(
            IdeaPostMediaRules.videoError(
              width: size.$1,
              height: size.$2,
              duration: const Duration(seconds: 120),
              sizeBytes: 1024,
            ),
            isNull,
          );
        }
        expect(IdeaPostMediaRules.videoBadge(720, 1280), 'Reel 9:16');
        expect(IdeaPostMediaRules.videoBadge(1920, 1080), 'Video 16:9');
        expect(IdeaPostMediaRules.videoBadge(1080, 1080), 'Square');
      },
    );

    test('rejects a video longer than two minutes with a clear message', () {
      expect(
        IdeaPostMediaRules.videoError(
          width: 1920,
          height: 1080,
          duration: const Duration(seconds: 121),
          sizeBytes: 1024,
        ),
        contains('longer than 2 minutes'),
      );
    });

    test('classifies three photos as one graphic post', () {
      final result = IdeaPostMediaRules.classify([
        'one.jpg',
        'two.png',
        'three.webp',
      ]);
      expect(result.kind, IdeaPostMediaKind.photos);
      expect(result.files, hasLength(3));
      expect(result.error, isNull);
    });

    test('rejects a mixed photo and video selection', () {
      expect(
        IdeaPostMediaRules.classify(['cover.jpg', 'clip.mp4']).error,
        contains('Choose photos or a video'),
      );
    });
  });
}
