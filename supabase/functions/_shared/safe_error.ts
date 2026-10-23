const genericMessages: Record<string, string> = {
  AUTH_REQUIRED: 'Sign in to complete this request.',
  NOT_AUTHORIZED: 'You are not allowed to complete this request.',
  INVALID_REQUEST: 'The request could not be processed.',
  METHOD_NOT_ALLOWED: 'This request method is not supported.',
  MEDIA_NOT_STAGED: 'Post media metadata must be staged before validation.',
  FILE_TOO_LARGE: 'The uploaded file exceeds the allowed size.',
  UNSUPPORTED_FILE: 'The uploaded file type is not supported.',
  MEDIA_INVALID: 'The uploaded media could not be verified.',
  MEDIA_VALIDATION_FAILED: 'The uploaded media could not be verified.',
  RATE_LIMITED: 'Too many requests. Please wait and try again.',
  UPSTREAM_UNAVAILABLE: 'The service provider is temporarily unavailable.',
  SERVICE_UNAVAILABLE: 'This service is temporarily unavailable.',
  INTERNAL_ERROR: 'The request could not be completed.',
  AI_REQUEST_FAILED: 'The AI service could not complete the request.',
  CONTACT_MATCH_FAILED: 'Contact matching could not be completed.',
  MUSIC_SEARCH_FAILED: 'The music catalogue could not complete the request.',
  STORY_CLEANUP_FAILED: 'Story cleanup could not be completed.',
};

const statusCodes: Record<number, string> = {
  400: 'INVALID_REQUEST',
  401: 'AUTH_REQUIRED',
  403: 'NOT_AUTHORIZED',
  404: 'INVALID_REQUEST',
  405: 'METHOD_NOT_ALLOWED',
  409: 'MEDIA_NOT_STAGED',
  413: 'FILE_TOO_LARGE',
  415: 'UNSUPPORTED_FILE',
  422: 'MEDIA_INVALID',
  429: 'RATE_LIMITED',
  500: 'INTERNAL_ERROR',
  502: 'UPSTREAM_UNAVAILABLE',
  503: 'SERVICE_UNAVAILABLE',
};

export function errorResponseBody(
  body: unknown,
  status: number,
): { error: string; code: string } | null {
  if (!body || typeof body !== 'object' || !('error' in body)) return null;
  const requestedCode = 'code' in body && typeof body.code === 'string' ? body.code : null;
  const code = requestedCode ?? statusCodes[status] ?? 'INTERNAL_ERROR';
  return { error: genericMessages[code] ?? genericMessages.INTERNAL_ERROR, code };
}

export function logSafeError(code: string, error: unknown): void {
  const name = error instanceof Error
    ? error.name.replace(/[^A-Za-z0-9_.-]/g, '').slice(0, 60) || 'Error'
    : 'NonError';
  const raw = error instanceof Error ? error.message : 'Non-Error exception';
  const detail = raw
    .replace(/https?:\/\/[^\s"'<>]+/gi, '[url]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[email]')
    .replace(/\bBearer\s+\S+/gi, 'Bearer [redacted]')
    .replace(/\b(?:eyJ[A-Za-z0-9_-]{20,}|sb_(?:secret|publishable)_[A-Za-z0-9_-]+|AIza[A-Za-z0-9_-]{20,})\b/g, '[secret]')
    .replace(/\b(password|token|secret|api[-_ ]?key|authorization)(\s*[:=]\s*)[^\s,;]+/gi, '$1$2[redacted]')
    .replace(/\b[0-9a-f]{8}-[0-9a-f-]{27,}\b/gi, '[id]')
    .replace(/(?:[A-Za-z]:\\|\/)(?:[^\s\\/]+[\\/])+[^\s\\/]*/g, '[path]')
    .replace(/(["'`])[^"'`]{1,300}\1/g, '[quoted content]')
    .slice(0, 400);
  console.error(`[${code}] ${name}: ${detail || 'No safe diagnostic detail.'}`);
}
