/// Removes invisible control and bidirectional override characters from text
/// that is displayed as user identity or profile copy.
class UserInputSanitizer {
  static final RegExp _unsafeControls = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  static String profileText(String value) =>
      value.replaceAll(_unsafeControls, '').trim();
}
