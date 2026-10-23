import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

Future<XFile?> compressIdeaVideo(XFile file) async {
  final info = await VideoCompress.compressVideo(
    file.path,
    quality: VideoQuality.Res1280x720Quality,
    deleteOrigin: false,
    includeAudio: true,
  );
  final path = info?.path;
  return path == null || path.isEmpty ? null : XFile(path);
}
