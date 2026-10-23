import 'dart:typed_data';

class MusicUploadResponse {
  const MusicUploadResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

Future<MusicUploadResponse> sendMusicUpload({
  required Uri uri,
  required Uint8List bytes,
  required Map<String, String> headers,
  required void Function(int sent, int total) onProgress,
}) => throw UnsupportedError('Music uploads are not supported on this platform.');
