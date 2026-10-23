import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'video_frame_picker_stub.dart'
    if (dart.library.io) 'video_frame_picker_io.dart' as platform;

Future<List<Uint8List>> generateVideoFrameCovers(
  XFile video,
  Duration duration,
) => platform.generateVideoFrameCovers(video, duration);
