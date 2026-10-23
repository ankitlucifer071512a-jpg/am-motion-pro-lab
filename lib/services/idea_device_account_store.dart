import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IdeaDeviceAccount {
  const IdeaDeviceAccount({required this.id, required this.name, required this.email, required this.refreshToken, this.avatarUrl});
  final String id;
  final String name;
  final String email;
  final String refreshToken;
  final String? avatarUrl;
}

/// Android-only account token vault. Native storage encrypts each value with an
/// AES-GCM key held in Android Keystore; refresh tokens never enter preferences.
class IdeaDeviceAccountStore {
  IdeaDeviceAccountStore._();
  static final instance = IdeaDeviceAccountStore._();
  static const _channel = MethodChannel('am_motion_lab/account_vault');
  static const _prefix = 'account.';
  static const _indexKey = 'account.index';
  StreamSubscription<AuthState>? _subscription;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void attach(SupabaseClient client) {
    if (!supported || _subscription != null) return;
    _subscription = client.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (session != null) unawaited(_saveSession(session));
    });
    final current = client.auth.currentSession;
    if (current != null) unawaited(_saveSession(current));
  }

  Future<void> _write(String key, String value) =>
      _channel.invokeMethod<void>('write', {'key': key, 'value': value});

  Future<Map<String, String>> _readAll() async {
    final value = await _channel.invokeMapMethod<String, String>('readAll');
    return value ?? <String, String>{};
  }

  Future<void> _delete(String key) =>
      _channel.invokeMethod<void>('delete', {'key': key});

  Future<void> _saveSession(Session session) async {
    final refreshToken = session.refreshToken;
    if (!supported || refreshToken == null || refreshToken.isEmpty) return;
    final user = session.user;
    final id = user.id;
    final values = await _readAll();
    final ids = (jsonDecode(values[_indexKey] ?? '[]') as List).cast<String>();
    if (!ids.contains(id)) ids.add(id);
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final display = (metadata['display_name'] ?? metadata['full_name'] ?? user.email ?? 'AM Motion Lab account').toString();
    await _write(_key(id, 'refresh'), refreshToken);
    await _write(_key(id, 'name'), display);
    await _write(_key(id, 'email'), user.email ?? '');
    await _write(_key(id, 'avatar'), (metadata['avatar_url'] ?? metadata['picture'] ?? '').toString());
    await _write(_indexKey, jsonEncode(ids));
  }

  String _key(String id, String part) => '$_prefix$id.$part';

  Future<List<IdeaDeviceAccount>> accounts() async {
    if (!supported) return const [];
    final values = await _readAll();
    final ids = (jsonDecode(values[_indexKey] ?? '[]') as List).cast<String>();
    return [
      for (final id in ids)
        if (values[_key(id, 'refresh')] case final refresh?)
          IdeaDeviceAccount(
            id: id,
            name: values[_key(id, 'name')] ?? 'AM Motion Lab account',
            email: values[_key(id, 'email')] ?? '',
            refreshToken: refresh,
            avatarUrl: (values[_key(id, 'avatar')] ?? '').isEmpty ? null : values[_key(id, 'avatar')],
          ),
    ];
  }

  Future<void> switchTo(SupabaseClient client, IdeaDeviceAccount account) async {
    if (!supported) throw UnsupportedError('Account switching is available in the Android app only.');
    await client.auth.setSession(account.refreshToken);
  }

  Future<void> remove(String id) async {
    if (!supported) throw UnsupportedError('Account management is available in the Android app only.');
    final values = await _readAll();
    final ids = (jsonDecode(values[_indexKey] ?? '[]') as List).cast<String>()..remove(id);
    await _delete(_key(id, 'refresh'));
    await _delete(_key(id, 'name'));
    await _delete(_key(id, 'email'));
    await _delete(_key(id, 'avatar'));
    await _write(_indexKey, jsonEncode(ids));
  }
}
