import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/creative_project.dart';

/// Device-local project persistence. Can be replaced by an authenticated backend later.
class CreativeProjectStore {
  CreativeProjectStore._();
  static final instance = CreativeProjectStore._();
  static const _key = 'creative_projects_v1';
  static const _goalKey = 'creative_learning_goal_v1';

  Future<String?> getGoal() async =>
      (await SharedPreferences.getInstance()).getString(_goalKey);

  Future<void> setGoal(String goal) async =>
      (await SharedPreferences.getInstance()).setString(_goalKey, goal);

  Future<List<CreativeProject>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    if (encoded == null) return [];
    try {
      final data = jsonDecode(encoded) as List<Object?>;
      return data
          .whereType<Map<String, Object?>>()
          .map(CreativeProject.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> save(CreativeProject project) async {
    final all = await getAll();
    final index = all.indexWhere((item) => item.id == project.id);
    if (index < 0) {
      all.insert(0, project);
    } else {
      all[index] = project;
    }
    await _write(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll()
      ..removeWhere((project) => project.id == id);
    await _write(all);
  }

  Future<void> _write(List<CreativeProject> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final project in projects) project.toJson()]),
    );
  }
}
