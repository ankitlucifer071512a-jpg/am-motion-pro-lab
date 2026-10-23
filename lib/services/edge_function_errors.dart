class EdgeFunctionErrors {
  static String friendlyMessage(
    Object? data, {
    required String fallback,
    int? status,
  }) {
    final body = data is Map ? data : const <Object?, Object?>{};
    final code = body['code']?.toString();
    switch (code) {
      case 'AUTH_REQUIRED':
      case 'SESSION_INVALID':
        return 'Your session expired. Sign in again and retry.';
      case 'NOT_AUTHORIZED':
        return 'You are not allowed to complete that request.';
      case 'RATE_LIMITED':
        return 'Too many requests. Please wait and try again.';
      case 'MEDIA_NOT_STAGED':
        return body['error'] is String
            ? body['error'] as String
            : 'Post media metadata must be staged before validation.';
      case 'FILE_TOO_LARGE':
        return 'The uploaded file exceeds the allowed size.';
      case 'UNSUPPORTED_FILE':
      case 'MEDIA_INVALID':
      case 'MEDIA_VALIDATION_FAILED':
        return 'The uploaded media could not be verified. Check the file and try again.';
      case 'SERVICE_UNAVAILABLE':
        return 'This service is temporarily unavailable. Please try again later.';
      case 'UPSTREAM_UNAVAILABLE':
        return 'The service provider is temporarily unavailable. Please try again later.';
      case 'INVALID_REQUEST':
        return 'The request could not be processed. Check your input and try again.';
      case 'AI_REQUEST_FAILED':
        return 'The AI service could not complete that request. Please try again.';
      case 'CONTACT_MATCH_FAILED':
        return 'Contact matching is temporarily unavailable. Please try again.';
      case 'MUSIC_SEARCH_FAILED':
        return 'The music catalogue is temporarily unavailable. Please try again.';
      case 'INTERNAL_ERROR':
      case 'STORY_CLEANUP_FAILED':
      case 'REQUEST_FAILED':
        return fallback;
    }

    // The media staging conflict intentionally retains its existing server
    // message and HTTP 409 behavior for older deployed validators.
    if (status == 409 && body['error'] is String) {
      return body['error'] as String;
    }
    return fallback;
  }
}
