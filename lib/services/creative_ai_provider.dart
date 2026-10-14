/// Minimal boundary for a future authenticated, server-side AI integration.
/// Provider credentials must never be stored in the Flutter client.
abstract interface class CreativeAiProvider {
  bool get isConfigured;
  Future<String> answer(String prompt);
}

class CreativeAiNotConfiguredException implements Exception {
  const CreativeAiNotConfiguredException();

  @override
  String toString() =>
      'AM Creative AI is not connected to a secure AI service yet.';
}

class UnconfiguredCreativeAiProvider implements CreativeAiProvider {
  const UnconfiguredCreativeAiProvider();

  @override
  bool get isConfigured => false;

  @override
  Future<String> answer(String prompt) async =>
      throw const CreativeAiNotConfiguredException();
}

class CreativeAiService {
  CreativeAiService({CreativeAiProvider? provider})
      : _provider = provider ?? const UnconfiguredCreativeAiProvider();

  final CreativeAiProvider _provider;
  bool get isConfigured => _provider.isConfigured;

  Future<String> ask(String prompt) {
    final text = prompt.trim();
    if (text.isEmpty) {
      throw ArgumentError.value(prompt, 'prompt', 'cannot be empty');
    }
    return _provider.answer(text);
  }
}
