// XMLHttpRequest is used here because its upload event reports actual browser
// upload progress; the default web HTTP client buffers a streamed request first.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'creator_music_uploader_stub.dart' show MusicUploadResponse;

Future<MusicUploadResponse> sendMusicUpload({
  required Uri uri,
  required Uint8List bytes,
  required Map<String, String> headers,
  required void Function(int sent, int total) onProgress,
}) {
  final completer = Completer<MusicUploadResponse>();
  final request = html.HttpRequest();
  request
    ..open('POST', uri.toString())
    ..responseType = 'text';
  for (final header in headers.entries) {
    request.setRequestHeader(header.key, header.value);
  }
  request.upload.onProgress.listen((event) {
    if (event.lengthComputable) onProgress(event.loaded ?? 0, event.total ?? bytes.length);
  });
  request.onLoad.listen((_) {
    if (!completer.isCompleted) {
      completer.complete(MusicUploadResponse(request.status ?? 0, request.responseText ?? ''));
    }
  });
  request.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Network error while uploading. Check your connection and try again.'));
    }
  });
  request.onAbort.listen((_) {
    if (!completer.isCompleted) completer.completeError(StateError('Upload was cancelled.'));
  });
  request.send(bytes);
  onProgress(0, bytes.length);
  return completer.future.timeout(const Duration(minutes: 2));
}
