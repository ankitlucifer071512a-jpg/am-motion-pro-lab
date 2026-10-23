import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/creator_audio.dart';
import '../screens/idea_lab/idea_music_upload_screen.dart';
import '../services/creator_music_service.dart';
import 'glass_card.dart';

class CreatorMusicList extends StatefulWidget {
  const CreatorMusicList({
    super.key,
    required this.ownerId,
    required this.isOwner,
  });

  final String ownerId;
  final bool isOwner;

  @override
  State<CreatorMusicList> createState() => _CreatorMusicListState();
}

class _CreatorMusicListState extends State<CreatorMusicList> {
  final _service = CreatorMusicService();
  List<CreatorAudio> _tracks = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CreatorMusicList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final tracks = await _service.forProfile(widget.ownerId);
      if (mounted) setState(() { _tracks = tracks; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _loading = false; });
    }
  }

  Future<void> _upload() async {
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const IdeaMusicUploadScreen()),
    );
    if (uploaded == true) await _load();
  }

  Future<void> _edit(CreatorAudio track) async {
    final title = TextEditingController(text: track.title);
    final genre = TextEditingController(text: track.genre);
    final description = TextEditingController(text: track.description);
    Uint8List? coverBytes;
    String? coverName;
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
        Future<void> chooseCover() async {
          final image = await ImagePicker().pickImage(source: ImageSource.gallery);
          if (image == null) return;
          final data = await image.readAsBytes();
          setDialogState(() { coverBytes = data; coverName = image.name; error = null; });
        }

        return AlertDialog(
          title: const Text('Edit audio'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, maxLength: 160, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: genre, maxLength: 80, decoration: const InputDecoration(labelText: 'Genre')),
            TextField(controller: description, maxLength: 3000, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: saving ? null : chooseCover, icon: const Icon(Icons.image_outlined), label: Text(coverName ?? 'Change cover'))),
            if (error != null) Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
          ])),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: saving ? null : () async {
              setDialogState(() { saving = true; error = null; });
              try {
                await _service.updateTrack(
                  track: track,
                  title: title.text,
                  genre: genre.text,
                  description: description.text,
                  coverBytes: coverBytes,
                  coverFilename: coverName,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (e) {
                setDialogState(() { saving = false; error = '$e'.replaceFirst('Bad state: ', ''); });
              }
            }, child: Text(saving ? 'Saving…' : 'Save')),
          ],
        );
      }),
    );
    title.dispose();
    genre.dispose();
    description.dispose();
    if (saved == true) await _load();
  }

  Future<void> _delete(CreatorAudio track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete audio?'),
        content: Text('“${track.title}” and its uploaded files will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteTrack(track);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Could not completely delete audio: $error');
        await _load();
      }
    }
  }

  Future<void> _showModerationNote(CreatorAudio track) async {
    try {
      final note = await _service.ownModerationNote(track.id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('Review note'),
        content: Text(note?.trim().isNotEmpty == true ? note! : 'No review note is available.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ));
    } catch (error) {
      if (mounted) _message('Could not load the review note: $error');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.isOwner) ...[
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(
          onPressed: _upload,
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Upload music'),
        )),
        const SizedBox(height: 10),
      ],
      if (_loading)
        const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
      else if (_error != null)
        GlassCard(child: Column(children: [
          Text('Could not load music. Check your connection and music database setup.\n$_error', textAlign: TextAlign.center, style: AppText.caption),
          TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]))
      else if (_tracks.isEmpty)
        GlassCard(child: Column(children: [
          const Icon(Icons.music_note_rounded, color: AppColors.sky, size: 34),
          const SizedBox(height: 7),
          Text(widget.isOwner ? 'You have not uploaded music yet.' : 'No approved music yet.', style: AppText.body),
          if (widget.isOwner) ...[
            const SizedBox(height: 7),
            Text('Your uploads will appear here after review.', style: AppText.caption),
          ],
        ]))
      else
        for (final track in _tracks) ...[
          _trackCard(track),
          const SizedBox(height: 9),
        ],
    ]);
  }

  Widget _trackCard(CreatorAudio track) => GlassCard(
        padding: const EdgeInsets.all(11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 68,
              height: 68,
              child: track.coverSignedUrl == null
                  ? _coverFallback()
                  : Image.network(track.coverSignedUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverFallback()),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.h3),
            const SizedBox(height: 3),
            Text(track.genre.isEmpty ? 'Music' : track.genre, style: AppText.caption),
            const SizedBox(height: 5),
            Wrap(spacing: 8, children: [
              _statusChip(track),
              Text('▶ ${track.plays}', style: AppText.caption),
              Text('♥ ${track.likes}', style: AppText.caption),
            ]),
          ])),
          if (widget.isOwner)
            PopupMenuButton<String>(
              tooltip: 'Music options',
              onSelected: (value) {
                if (value == 'edit') _edit(track);
                if (value == 'delete') _delete(track);
                if (value == 'note') _showModerationNote(track);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit details')),
                PopupMenuItem(value: 'note', child: Text('Review note')),
                PopupMenuItem(value: 'delete', child: Text('Delete audio')),
              ],
            ),
        ]),
      );

  Widget _coverFallback() => Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(child: Image.asset('assets/brand/icon_logo.png', width: 42, height: 42, fit: BoxFit.contain)),
      );

  Widget _statusChip(CreatorAudio track) {
    final color = switch (track.status) {
      'approved' => Colors.greenAccent,
      'hidden' || 'removed' => Colors.orangeAccent,
      _ => AppColors.sky,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(track.statusLabel, style: AppText.caption.copyWith(color: color, fontSize: 10)),
    );
  }
}
