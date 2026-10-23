class PasswordRecoveryRules {
  // Supabase's default minimum is 6; adjust this constant if the project
  // Authentication password policy is configured to require more characters.
  static const minimumLength = 6;
  static const maximumResendsPerSession = 3;
  static const resendDelaySeconds = 60;

  static int nextCountdownValue(int current) => current > 0 ? current - 1 : 0;

  static bool isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  static bool isValidCode(String value) => RegExp(r'^\d{6}$').hasMatch(value);

  static bool isValidPassword(String value) => value.length >= minimumLength;

  static String maskEmail(String value) {
    final parts = value.trim().split('@');
    if (parts.length != 2) return value;
    final local = parts.first;
    final visible = local.isEmpty ? '' : local.substring(0, 1);
    return '$visible***@${parts.last}';
  }

  static String? passwordError(String value) =>
      value.length < minimumLength ? 'Use at least $minimumLength characters.' : null;
}
