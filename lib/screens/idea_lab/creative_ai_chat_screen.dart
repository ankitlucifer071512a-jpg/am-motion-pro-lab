import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/creative_ai_provider.dart';
import '../../widgets/app_emoji_picker_button.dart';

class CreativeAiChatScreen extends StatefulWidget {
  const CreativeAiChatScreen({super.key});

  @override
  State<CreativeAiChatScreen> createState() => _CreativeAiChatScreenState();
}

class _CreativeAiChatScreenState extends State<CreativeAiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _ai = CreativeAiService();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  static const _prompts = [
    'Help me learn video editing.',
    'Give me a motion graphics idea.',
    'Explain 3D animation basics.',
    'Help me plan a creative project.',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggested]) async {
    final text = (suggested ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 1200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please keep each message under 1,200 characters.')),
      );
      return;
    }
    _input.clear();
    final userMessage = _ChatMessage(
      text: text,
      isUser: true,
      at: DateTime.now(),
    );
    setState(() {
      _sending = true;
      _messages.add(userMessage);
    });
    _toBottom();
    try {
      final conversation = _conversationFor(userMessage);
      final answer = await _ai.askConversation(conversation);
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(text: answer, isUser: false, at: DateTime.now()),
        ),
      );
    } on CreativeAiException catch (error) {
      // Keep the failed message visible, but do not send it as conversation
      // history on the next turn (which could create consecutive user roles).
      userMessage.includeInContext = false;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _toBottom();
      }
    }
  }

  List<Map<String, String>> _conversationFor(_ChatMessage current) {
    final previous = _messages
        .where((message) => !identical(message, current) && message.includeInContext)
        .toList();

    // Gemini limits each message and the whole request. Old assistant replies
    // can be long, so send concise recent context while keeping the UI history.
    final recent = previous.length > 10
        ? previous.sublist(previous.length - 10)
        : previous;
    final messages = <Map<String, String>>[];
    var totalChars = 0;
    for (final message in recent) {
      final clipped = message.text.length > 900
          ? message.text.substring(0, 900)
          : message.text;
      if (totalChars + clipped.length > 6500) continue;
      messages.add({
        'role': message.isUser ? 'user' : 'model',
        'text': clipped,
      });
      totalChars += clipped.length;
    }

    // Gemini conversation history must begin with a user turn and alternate.
    while (messages.isNotEmpty && messages.first['role'] != 'user') {
      messages.removeAt(0);
    }
    while (messages.length > 1 && messages.last['role'] == messages[messages.length - 2]['role']) {
      messages.removeAt(messages.length - 2);
    }
    messages.add({'role': 'user', 'text': current.text});
    return messages;
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 700;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.sky),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AM Creative AI', style: AppText.h3),
                Text('Your creative learning buddy', style: AppText.caption),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      wide ? 32 : 18,
                      18,
                      wide ? 32 : 18,
                      18,
                    ),
                    children: [
                      if (_messages.isEmpty) ...[
                        const SizedBox(height: 24),
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.glassFillStrong,
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppColors.sky,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Let’s make something great.',
                          style: AppText.h2,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ask about courses, creative ideas, or your next project.',
                          style: AppText.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final prompt in _prompts)
                              ActionChip(
                                label: Text(prompt),
                                onPressed: _sending
                                    ? null
                                    : () => _send(prompt),
                                backgroundColor: AppColors.glassFillStrong,
                                side: const BorderSide(
                                  color: AppColors.glassBorder,
                                ),
                                labelStyle: const TextStyle(
                                  color: AppColors.ink,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      for (final message in _messages)
                        _Bubble(message: message),
                      if (_sending)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 32 : 14,
                    8,
                    wide ? 32 : 14,
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.glassFillStrong,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppEmojiPickerButton(controller: _input),
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  minLines: 1,
                                  maxLines: 5,
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    hintText: 'Message AM Creative AI…',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.at,
  });
  final String text;
  final bool isUser;
  final DateTime at;
  bool includeInContext = true;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.at).format(context);
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            gradient: message.isUser ? AppColors.brandGradient : null,
            color: message.isUser ? null : AppColors.glassFillStrong,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(message.isUser ? 18 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 18),
            ),
            border: message.isUser
                ? null
                : Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(message.text),
              ),
              const SizedBox(height: 4),
              Text(time, style: AppText.caption.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
