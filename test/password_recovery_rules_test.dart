import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/password_recovery_rules.dart';

void main() {
  group('PasswordRecoveryRules', () {
    test('validates email format', () {
      expect(PasswordRecoveryRules.isValidEmail('person@example.com'), isTrue);
      expect(PasswordRecoveryRules.isValidEmail(' person@example.com '), isTrue);
      expect(PasswordRecoveryRules.isValidEmail('person@'), isFalse);
      expect(PasswordRecoveryRules.isValidEmail('person example.com'), isFalse);
    });

    test('enforces configured minimum password length', () {
      expect(PasswordRecoveryRules.minimumLength, 6);
      expect(PasswordRecoveryRules.isValidPassword('abc12'), isFalse);
      expect(PasswordRecoveryRules.isValidPassword('abc123'), isTrue);
    });

    test('accepts exactly six numeric code digits', () {
      expect(PasswordRecoveryRules.isValidCode('012345'), isTrue);
      expect(PasswordRecoveryRules.isValidCode('12345'), isFalse);
      expect(PasswordRecoveryRules.isValidCode('12345x'), isFalse);
    });

    test('masks the email local part', () {
      expect(PasswordRecoveryRules.maskEmail('alex@example.com'), 'a***@example.com');
    });

    test('counts down to zero without going negative', () {
      expect(PasswordRecoveryRules.nextCountdownValue(60), 59);
      expect(PasswordRecoveryRules.nextCountdownValue(1), 0);
      expect(PasswordRecoveryRules.nextCountdownValue(0), 0);
      expect(PasswordRecoveryRules.maximumResendsPerSession, 3);
    });
  });
}
