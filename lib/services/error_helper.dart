/// Converts any raw exception/server error into a user-friendly message.
///
/// Preserves messages already written for end-users (network messages,
/// validation feedback, etc.) while suppressing HTTP status codes, stack
/// traces, raw JSON, and other technical noise.
String friendlyError(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  return _sanitize(raw);
}

String _sanitize(String raw) {
  final lower = raw.toLowerCase();

  // ── 1. Preserve messages our own services already wrote for users ────────
  const keepFragments = <String>[
    'unable to reach unibuzz',
    'check your internet',
    'request timed out',
    'network unavailable',
    'network request failed',
    'session expired',
    'please log in',
    'missing authentication tokens',
    'no refresh token',
    'missing access token',
    'too large',
    'no longer exists',
    'upload is not configured',
    'publishing is not configured',
    'upload cancelled',
    'processing failed',
    'processing and will appear',
    'video is still processing',
    'invalid email or password',
    'no profile fields',
    'unable to load profile',
    'unable to update profile',
    'unable to upload',
    'could not upload',
    'cloud upload',
    'no valid media url',
    'video file could not be found',
  ];

  for (final fragment in keepFragments) {
    if (lower.contains(fragment)) return raw;
  }

  // ── 2. Map common HTTP / server patterns ─────────────────────────────────
  if (_has(lower, ['500', '502', '503', '504', 'internal server error', 'server error', 'gateway'])) {
    return 'Our servers are having trouble right now. Please try again in a moment.';
  }
  if (_has(lower, ['401', 'unauthorized', 'unauthenticated'])) {
    return 'Your session has expired. Please log in again.';
  }
  if (_has(lower, ['403', 'forbidden', 'access denied'])) {
    return "You don't have permission to do that.";
  }
  if (_has(lower, ['404', 'not found']) && !lower.contains('file')) {
    return 'The requested content could not be found.';
  }
  if (_has(lower, ['409', 'conflict', 'duplicate', 'already registered', 'email already'])) {
    return 'An account with this email already exists. Try logging in instead.';
  }
  if (_has(lower, ['username', 'already taken'])) {
    return 'That username is already taken. Please choose a different one.';
  }
  if (_has(lower, ['429', 'rate limit', 'too many requests'])) {
    return 'Too many attempts. Please wait a moment and try again.';
  }
  if (_has(lower, ['400', 'bad request', 'invalid request'])) {
    return 'Please check your details and try again.';
  }
  if (_has(lower, ['validation', 'invalid field', 'required field'])) {
    return 'Please check your details and try again.';
  }
  if (_has(lower, ['connection refused', 'econnrefused'])) {
    return 'Unable to connect to the server. Please try again shortly.';
  }

  // ── 3. Suppress technical noise ──────────────────────────────────────────
  // Multi-line = stack trace; dart:/package: = internal error; { = JSON blob
  if (raw.contains('\n') ||
      raw.contains('dart:') ||
      raw.contains('package:') ||
      raw.contains('{') ||
      raw.contains('#0 ') ||
      raw.length > 220) {
    return 'Something went wrong. Please try again.';
  }

  // ── 4. Keep short, capitalised human-readable messages ───────────────────
  if (raw.length <= 140 && RegExp(r'^[A-Z]').hasMatch(raw)) {
    return raw;
  }

  return 'Something went wrong. Please try again.';
}

bool _has(String text, List<String> patterns) =>
    patterns.any(text.contains);
