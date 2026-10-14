import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_first_app/services/client_work_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and reloads a mission submission and checklist', () async {
    final store = ClientWorkStore.instance;
    await store.save('graphic', {
      'practice': true,
      'checks': [true, false],
      'link': 'https://example.com/project',
      'submitted': true,
    });

    final loaded = await store.load('graphic');
    expect(loaded['practice'], isTrue);
    expect(loaded['checks'], [true, false]);
    expect(loaded['link'], 'https://example.com/project');
    expect(loaded['submitted'], isTrue);
    expect((await store.load('video')), isEmpty);
  });
}
