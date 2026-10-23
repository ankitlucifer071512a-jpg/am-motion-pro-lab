import 'package:shared_preferences/shared_preferences.dart';

class IdeaBookmarkStore {
  IdeaBookmarkStore._();
  static final instance = IdeaBookmarkStore._();

  static const _key = 'idea_lab_bookmarks_v1';

  Future<Set<String>> get savedIds async =>
      (await SharedPreferences.getInstance())
          .getStringList(_key)
          ?.toSet() ??
      <String>{};

  Future<Set<String>> toggle(String ideaId) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(_key)?.toSet() ?? <String>{};
    if (!saved.add(ideaId)) saved.remove(ideaId);
    await preferences.setStringList(_key, saved.toList()..sort());
    return saved;
  }
}
