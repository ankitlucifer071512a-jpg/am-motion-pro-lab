import 'package:supabase_flutter/supabase_flutter.dart';

import 'edge_function_errors.dart';
import 'idea_lab_backend.dart';

/// Calls the authenticated Supabase Edge Function. Provider secrets stay server side.
class CreativeAiService {
  bool get isConfigured => IdeaLabBackend.isReady;

  Future<String> ask(String prompt) => askConversation([
    {'role': 'user', 'text': prompt},
  ]);

  Future<String> askConversation(List<Map<String, String>> conversation) async {
    if (!IdeaLabBackend.isReady || IdeaLabBackend.currentUser == null) {
      throw const CreativeAiNotConfiguredException();
    }
    try {
      final response = await IdeaLabBackend.client.functions.invoke(
        'creative-ai-chat',
        body: {'messages': conversation},
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300) {
        throw CreativeAiException(
          EdgeFunctionErrors.friendlyMessage(
            data,
            fallback: 'AI is temporarily unavailable. Please try again.',
            status: response.status,
          ),
        );
      }
      if (data is! Map ||
          data['reply'] is! String ||
          (data['reply'] as String).trim().isEmpty) {
        throw const CreativeAiException(
          'AI returned an empty reply. Please try again.',
        );
      }
      return (data['reply'] as String).trim();
    } on FunctionException catch (error) {
      final details = error.details;
      if (error.status == 0) {
        throw const CreativeAiException(
          'Could not connect to Supabase. Check your internet connection and try again.',
        );
      }
      if (error.status == 404) {
        throw const CreativeAiException(
          'The AI chat function is not deployed to Supabase yet.',
        );
      }
      if (error.status == 401 || error.status == 403) {
        throw const CreativeAiException(
          'Your sign-in session expired or the request was rejected. Sign in again.',
        );
      }
      if (error.status == 429) {
        throw CreativeAiException(
          EdgeFunctionErrors.friendlyMessage(
            details,
            fallback: 'AI usage is temporarily rate limited. Please try again later.',
            status: error.status,
          ),
        );
      }
      throw CreativeAiException(
        EdgeFunctionErrors.friendlyMessage(
          details,
          fallback: 'The AI service is temporarily unavailable. Please try again later.',
          status: error.status,
        ),
      );
    } on CreativeAiException {
      rethrow;
    } catch (_) {
      throw const CreativeAiException(
        'Could not reach the AI service. Check your connection and try again.',
      );
    }
  }
}

class CreativeAiNotConfiguredException extends CreativeAiException {
  const CreativeAiNotConfiguredException()
    : super('Sign in to use AM Creative AI.');
}

class CreativeAiException implements Exception {
  const CreativeAiException(this.message);
  final String message;
  @override
  String toString() => message;
}
