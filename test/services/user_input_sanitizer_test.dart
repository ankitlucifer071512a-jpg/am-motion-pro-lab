import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/user_input_sanitizer.dart';

void main() {
  group('UserInputSanitizer.profileText', () {
    test('removes control and bidirectional override characters', () {
      expect(
        UserInputSanitizer.profileText('  Al\u202Eice\u0000  '),
        'Alice',
      );
    });

    test('preserves ordinary Unicode and bio line breaks', () {
      expect(
        UserInputSanitizer.profileText(
          '  \u0906\u0930\u094d\u092f\u093e\nEditor  ',
        ),
        '\u0906\u0930\u094d\u092f\u093e\nEditor',
      );
    });
  });
}
