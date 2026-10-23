import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/creative_ai_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/premium_lighting.dart';

class _ChatMessage {
  const _ChatMessage(this.text, {this.fromUser = false, this.isStatus = false});
  final String text;
  final bool fromUser;
  final bool isStatus;
}

/// Premium chat shell backed by a provider interface. No client-side fake AI.
class StudioCoachScreen extends StatefulWidget {
  const StudioCoachScreen({super.key, this.service});
  final CreativeAiService? service;

  @override
  State<StudioCoachScreen> createState() => _StudioCoachScreenState();
}

class _StudioCoachScreenState extends State<StudioCoachScreen> {
  late final CreativeAiService _service = widget.service ?? CreativeAiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;

  static const _quickActions = [
    ('Create a video', 'Help me plan a short product video.'),
    ('Learn a skill', 'Teach me the basics of color harmony.'),
    ('Fix my problem', 'Help me diagnose a creative software problem.'),
    ('Create a brief', 'Create a short brief for a motion graphics reel.'),
    ('Explain animation', 'Explain an animation technique step by step.'),
    (
      'Review my game mistake',
      'Explain the learning point in my last challenge.',
    ),
    ('Find my next challenge', 'Suggest a next learning challenge.'),
    (
      'Plan a portfolio project',
      'Help me plan a portfolio project in manageable steps.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final prompt = (suggestion ?? _controller.text).trim();
    if (prompt.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(prompt, fromUser: true));
    });
    _jumpToBottom();
    try {
      final answer = await _service.ask(prompt);
      if (mounted) setState(() => _messages.add(_ChatMessage(answer)));
    } on CreativeAiNotConfiguredException {
      if (mounted) {
        setState(
          () => _messages.add(
            const _ChatMessage(
              'AM Creative AI is not connected yet. This app has no secure AI backend configured, so I can’t answer as an AI or see verified course progress. Once a protected server endpoint is configured, this chat can provide tutoring, project help, and progress-aware suggestions.',
              isStatus: true,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _messages.add(
            const _ChatMessage(
              'I could not reach the AI service. Check your connection and try again.',
              isStatus: true,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _jumpToBottom();
      }
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const AnimatedHeroOrb(
            size: 34,
            child: Icon(Icons.auto_awesome, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AM Creative AI', style: TextStyle(fontSize: 15)),
              Text('Creative learning assistant', style: AppText.caption),
            ],
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: GlassCard(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                Icon(
                  _service.isConfigured
                      ? Icons.cloud_outlined
                      : Icons.cloud_off_outlined,
                  color: AppColors.sky,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _service.isConfigured
                        ? 'Signed-in app ready. The server checks AI availability when you send a message.'
                        : 'Sign in and configure the secure AI server to send messages.',
                    style: AppText.caption.copyWith(color: AppColors.inkDim),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_messages.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('What would you like help with?', style: AppText.h2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 7,
              runSpacing: 2,
              children: [
                for (final action in _quickActions)
                  ActionChip(
                    avatar: const Icon(Icons.arrow_outward, size: 15),
                    label: Text(action.$1),
                    onPressed: () => _send(action.$2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'These actions need the secure AI service to be configured.',
                style: AppText.caption,
              ),
            ),
          ),
        ],
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          size: 42,
                          color: AppColors.inkFaint,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Your conversation will appear here.',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(15),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_sending && i == _messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final message = _messages[i];
                    return Align(
                      alignment: message.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          selected: message.fromUser,
                          padding: const EdgeInsets.all(13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.isStatus)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    'SERVICE STATUS',
                                    style: AppText.label.copyWith(fontSize: 9),
                                  ),
                                ),
                              Text(
                                message.text,
                                style: AppText.body.copyWith(fontSize: 13),
                              ),
                              if (!message.fromUser)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Copy response',
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: message.text),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Copied'),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 17,
                                      color: AppColors.inkFaint,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask AM Creative AI…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  tooltip: 'Send question',
                  icon: const Icon(Icons.send_rounded, color: AppColors.sky),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
