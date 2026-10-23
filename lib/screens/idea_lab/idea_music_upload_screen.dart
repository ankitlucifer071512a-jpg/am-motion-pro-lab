import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../services/creator_music_service.dart';
import '../../widgets/glass_card.dart';

class IdeaMusicUploadScreen extends StatefulWidget {
  const IdeaMusicUploadScreen({super.key});

  @override
  State<IdeaMusicUploadScreen> createState() => _IdeaMusicUploadScreenState();
}

class _IdeaMusicUploadScreenState extends State<IdeaMusicUploadScreen> {
  final _service = CreatorMusicService();
  final _title = TextEditingController();
  final _genre = TextEditingController();
  final _description = TextEditingController();
  Uint8List? _audioBytes;
  String? _audioName;
  Uint8List? _coverBytes;
  String? _coverName;
  bool _allowUse = false;
  bool _rightsConfirmed = false;
  bool _uploading = false;
  int _sent = 0;
  int _total = 0;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _genre.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'm4a'],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _audioName = file.name;
        _audioBytes = bytes;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not read the selected audio: $error');
    }
  }

  Future<void> _pickCover() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _coverName = file.name;
        _coverBytes = bytes;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not read the selected cover: $error');
    }
  }

  Future<void> _submit() async {
    if (_audioBytes == null || _audioName == null) {
      setState(() => _error = 'Choose an MP3 or M4A audio file first.');
      return;
    }
    if (!_rightsConfirmed) {
      setState(() => _error = 'Confirm that you own this music or have the rights to share it.');
      return;
    }
    setState(() { _uploading = true; _error = null; _sent = 0; _total = 0; });
    try {
      await _service.upload(
        audioBytes: _audioBytes!,
        audioFilename: _audioName!,
        coverBytes: _coverBytes,
        coverFilename: _coverName,
        title: _title.text,
        genre: _genre.text,
        description: _description.text,
        allowUseInVideos: _allowUse,
        onProgress: (sent, total) {
          if (mounted) setState(() { _sent = sent; _total = total; });
        },
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload submitted. Your music is pending review.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() { _uploading = false; _error = _friendlyError(error); });
    }
  }

  String _friendlyError(Object error) => '$error'
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Exception: ', '');

  String _formatBytes(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? null : (_sent / _total).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Upload music')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text('YOUR MUSIC', style: AppText.label),
        const SizedBox(height: 5),
        Text('Share your sound', style: AppText.h1),
        const SizedBox(height: 14),
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAudio,
            icon: const Icon(Icons.audio_file_outlined),
            label: Text(_audioName == null ? 'Choose MP3 or M4A' : _audioName!),
          ),
          if (_audioBytes != null) Text('${_formatBytes(_audioBytes!.length)} · 10 MB max', style: AppText.caption),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickCover,
            icon: const Icon(Icons.image_outlined),
            label: Text(_coverName == null ? 'Add cover image (optional)' : _coverName!),
          ),
          if (_coverBytes != null) Text('${_formatBytes(_coverBytes!.length)} · 2 MB max', style: AppText.caption),
          TextButton.icon(
            onPressed: _uploading || _coverBytes == null ? null : () => setState(() { _coverBytes = null; _coverName = null; }),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove cover'),
          ),
          TextField(controller: _title, maxLength: 160, decoration: const InputDecoration(labelText: 'Title *')),
          TextField(controller: _genre, maxLength: 80, decoration: const InputDecoration(labelText: 'Genre')),
          TextField(controller: _description, maxLength: 3000, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _allowUse,
              onChanged: _uploading ? null : (value) => setState(() => _allowUse = value),
              title: const Text('Allow others to use this audio in their videos'),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _rightsConfirmed,
              onChanged: _uploading ? null : (value) => setState(() => _rightsConfirmed = value ?? false),
              title: const Text('This music is mine, or I have the rights to share it. *'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppText.body.copyWith(color: Colors.redAccent)),
          ],
          if (_uploading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(_total > 0 ? 'Uploading ${_formatBytes(_sent)} of ${_formatBytes(_total)}' : 'Preparing upload…', style: AppText.caption),
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _uploading ? null : _submit,
            icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
            label: Text(_uploading ? 'Uploading…' : 'Upload for review'),
          )),
          const SizedBox(height: 5),
          Text('New uploads are private until approved by a moderator.', style: AppText.caption),
        ])),
      ]),
    );
  }
}
