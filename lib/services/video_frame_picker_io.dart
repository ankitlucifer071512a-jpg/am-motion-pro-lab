import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

Future<List<Uint8List>> generateVideoFrameCovers(
  XFile video,
  Duration duration,
) async {
  if (duration <= Duration.zero) return const [];
  final fractions = [0.08, 0.25, 0.42, 0.59, 0.76, 0.92];
  final frames = <Uint8List>[];
  for (final fraction in fractions) {
    final data = await VideoThumbnail.thumbnailData(
      video: video.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 480,
      maxHeight: 640,
      timeMs: (duration.inMilliseconds * fraction).round(),
      quality: 82,
    );
    if (data != null && data.isNotEmpty) frames.add(data);
  }
  return frames;
}
