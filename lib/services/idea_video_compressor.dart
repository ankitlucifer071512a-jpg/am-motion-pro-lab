import 'package:image_picker/image_picker.dart';

import 'idea_video_compressor_stub.dart'
    if (dart.library.io) 'idea_video_compressor_io.dart' as implementation;

Future<XFile?> compressIdeaVideo(XFile file) =>
    implementation.compressIdeaVideo(file);
