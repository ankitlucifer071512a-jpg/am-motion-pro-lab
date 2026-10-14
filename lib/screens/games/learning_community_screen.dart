import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class _LocalPost {
  _LocalPost({this.text, this.image, required this.time});
  final String? text;
  final Uint8List? image;
  final String time;
}

/// Local preview of a student room. A shared backend is required for delivery
/// to other students; the screen never claims that demo posts are public.
class LearningCommunityScreen extends StatefulWidget {
  const LearningCommunityScreen({super.key});
  @override
  State<LearningCommunityScreen> createState() =>
      _LearningCommunityScreenState();
}

class _LearningCommunityScreenState extends State<LearningCommunityScreen> {
  final _picker = ImagePicker();
  final _message = TextEditingController();
  final _posts = <_LocalPost>[];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _attachImage() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(
          () => _posts.insert(0, _LocalPost(image: bytes, time: 'Just now')));
    }
  }

  void _sendMessage() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _posts.insert(0, _LocalPost(text: text, time: 'Just now'));
      _message.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Student group room')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.sky),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Text(
                              'Local preview only. Images and messages appear on this device; student-wide sharing needs a group chat service.',
                              style: AppText.caption))
                    ]))),
        Expanded(
            child: _posts.isEmpty
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.forum_outlined,
                              color: AppColors.sky, size: 44),
                          const SizedBox(height: 10),
                          Text('Start a creative conversation',
                              style: AppText.h3),
                          const SizedBox(height: 5),
                          Text(
                              'Share a reference image or ask classmates a question.',
                              textAlign: TextAlign.center,
                              style: AppText.caption)
                        ])))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _posts.length,
                    itemBuilder: (context, i) {
                      final post = _posts[i];
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 330),
                                  child: GlassCard(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (post.image != null)
                                              ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.memory(
                                                      post.image!,
                                                      fit: BoxFit.cover,
                                                      width: 300,
                                                      height: 200)),
                                            if (post.text != null)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(post.text!,
                                                      style: AppText.body)),
                                            const SizedBox(height: 5),
                                            Text(
                                                'You • ${post.time} • local preview',
                                                style: AppText.caption)
                                          ])))));
                    })),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(children: [
                  IconButton(
                      tooltip: 'Share an image',
                      onPressed: _attachImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.sky)),
                  Expanded(
                      child: TextField(
                          controller: _message,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                              hintText: 'Write to the group…', isDense: true))),
                  const SizedBox(width: 8),
                  IconButton(
                      tooltip: 'Send message',
                      onPressed: _sendMessage,
                      icon:
                          const Icon(Icons.send_rounded, color: AppColors.sky))
                ]))),
      ]));
}
