import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'password_recovery_rules.dart';

class PasswordRecoveryService {
  static const _pendingKey = 'password_recovery_verified_pending';
  static final recoveryInProgress = ValueNotifier<bool>(false);

  static bool get isRecoveryInProgress => recoveryInProgress.value;

  Future<void> sendCode(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> verifyCode(String email, String code) async {
    await _verify(() => Supabase.instance.client.auth.verifyOTP(
          email: email.trim(),
          token: code,
          type: OtpType.recovery,
        ));
  }

  Future<void> _verify(Future<AuthResponse> Function() verify) async {
    // Mark the recovery flow before verification so a restart after the server
    // accepts the OTP cannot leave a partial recovery session active.
    recoveryInProgress.value = true;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, true);
      await verify();
    } catch (_) {
      // A network failure can happen after the server verified the OTP but
      // before the client received the response. Revoke any local session in
      // that ambiguous case instead of exposing it through the auth gate.
      try {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Best effort; never replace the original verification error.
      }
      try {
        await prefs?.remove(_pendingKey);
      } catch (_) {
        // A leftover marker is safe: startup cleanup signs out locally.
      }
      recoveryInProgress.value = false;
      rethrow;
    }
  }

  Future<void> savePassword(String password) async {
    await Supabase.instance.client.auth.updateUser(UserAttributes(password: password));
    // Keep the recovery session active for this device; revoke all other sessions.
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.others);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    recoveryInProgress.value = false;
  }

  Future<void> abandon() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) == true) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Cleanup is best effort; never surface raw auth exceptions here.
      }
    }
    await prefs.remove(_pendingKey);
    recoveryInProgress.value = false;
  }

  Future<void> cleanupInterruptedRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) == true) await abandon();
  }

  static String friendlyError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final text = '$code ${error.message}'.toLowerCase();
      if (error.statusCode == '429' || text.contains('rate') ||
          text.contains('too many') || code.contains('limit')) {
        return 'Too many requests. Please wait before trying again.';
      }
      if (text.contains('token') || text.contains('otp') || text.contains('expired')) {
        return 'That code is invalid or expired. Request a new code and try again.';
      }
      if (text.contains('password') && (text.contains('same') || text.contains('different'))) {
        return 'Choose a password you have not used before.';
      }
      if (text.contains('password')) return 'That password does not meet the account requirements.';
      if (text.contains('network') || text.contains('fetch')) {
        return 'No internet connection. Check your connection and try again.';
      }
    }
    return 'We could not complete that step. Check your connection and try again.';
  }

  static void reportSafeAuthFailure(Object error, String friendlyMessage) {
    if (!kDebugMode || error is! AuthException) return;
    final rawCode = error.code ?? 'unclassified';
    final safeCode = RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(rawCode)
        ? rawCode
        : 'unclassified';
    final rawStatus = error.statusCode ?? 'unknown';
    final safeStatus = RegExp(r'^\d{3}$').hasMatch(rawStatus)
        ? rawStatus
        : 'unknown';
    debugPrint(
      'Supabase Auth failure: status=$safeStatus code=$safeCode message=$friendlyMessage',
    );
  }

  static Future<bool> hasInterruptedRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey) == true;
  }
}
