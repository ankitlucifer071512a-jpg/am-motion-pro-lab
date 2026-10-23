import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'creator_music_uploader_stub.dart' show MusicUploadResponse;

Future<MusicUploadResponse> sendMusicUpload({
  required Uri uri,
  required Uint8List bytes,
  required Map<String, String> headers,
  required void Function(int sent, int total) onProgress,
}) async {
  final request = http.StreamedRequest('POST', uri)
    ..contentLength = bytes.length
    ..headers.addAll(headers);
  final client = http.Client();
  try {
    final responseFuture = client.send(request);
    await request.sink.addStream(_chunks(bytes, onProgress));
    await request.sink.close();
    final response = await responseFuture.timeout(const Duration(minutes: 2));
    return MusicUploadResponse(response.statusCode, await response.stream.bytesToString());
  } on TimeoutException {
    throw StateError('Upload timed out. Check your connection and try again.');
  } finally {
    client.close();
  }
}

Stream<List<int>> _chunks(Uint8List bytes, void Function(int, int) onProgress) async* {
  const chunkSize = 64 * 1024;
  var sent = 0;
  onProgress(0, bytes.length);
  for (var offset = 0; offset < bytes.length; offset += chunkSize) {
    final end = min(offset + chunkSize, bytes.length);
    final chunk = Uint8List.sublistView(bytes, offset, end);
    sent += chunk.length;
    onProgress(sent, bytes.length);
    yield chunk;
  }
}
