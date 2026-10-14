import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local prototype progress, using the same device storage approach as lessons.
class ClientWorkStore {
  ClientWorkStore._();
  static final instance = ClientWorkStore._();
  static const _key = 'client_work_missions_v1';

  Future<Map<String, dynamic>> load(String missionId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _read(prefs.getString(_key));
    return Map<String, dynamic>.from(all[missionId] as Map? ?? const {});
  }

  Future<void> save(String missionId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _read(prefs.getString(_key));
    all[missionId] = data;
    await prefs.setString(_key, jsonEncode(all));
  }

  Future<Map<String, Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs.getString(_key)).map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)));
  }

  Map<String, dynamic> _read(String? raw) {
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    }
  }
}
