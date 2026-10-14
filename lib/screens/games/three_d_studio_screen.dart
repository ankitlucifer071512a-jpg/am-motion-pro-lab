import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ThreeDStudioScreen extends StatefulWidget {
  const ThreeDStudioScreen({super.key});

  @override
  State<ThreeDStudioScreen> createState() => _ThreeDStudioScreenState();
}

class _ThreeDStudioScreenState extends State<ThreeDStudioScreen> {
  String? _source;
  String? _modelName;
  String? _error;
  int? _modelBytes;
  bool _loading = false;

  Future<void> _importModel() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a 3D model (.glb)',
        type: FileType.custom,
        allowedExtensions: const ['glb'],
      );
      if (!mounted) return;
      if (file == null) {
        setState(() => _loading = false);
        return;
      }

      final length = await file.length();
      if (length == null || length == 0) {
        throw const FormatException('This file is empty or cannot be read.');
      }
      if (length > 20 * 1024 * 1024) {
        throw const FormatException(
            'Please choose a GLB model smaller than 20 MB.');
      }
      final bytes = await file.readAsBytes();
      final isGlb = bytes.length >= 4 &&
          bytes[0] == 0x67 &&
          bytes[1] == 0x6c &&
          bytes[2] == 0x54 &&
          bytes[3] == 0x46;
      if (!isGlb || file.extension?.toLowerCase() != 'glb') {
        throw const FormatException(
            'The selected file is not a valid GLB model.');
      }

      final source = kIsWeb
          ? 'data:model/gltf-binary;base64,${base64Encode(bytes)}'
          : file.path != null
              ? Uri.file(file.path!).toString()
              : 'data:model/gltf-binary;base64,${base64Encode(bytes)}';
      setState(() {
        _source = source;
        _modelName = file.name;
        _modelBytes = length;
        _loading = false;
      });
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not import that model. Try a valid .glb file.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('3D Model Studio')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text('YOUR 3D WORKSPACE', style: AppText.label),
              const SizedBox(height: 6),
              Text('Bring a model to life', style: AppText.h1),
              const SizedBox(height: 7),
              Text(
                  'Import a GLB file and inspect it in an interactive 3D viewer. Drag to orbit and use pinch or scroll to zoom.',
                  style: AppText.body),
              const SizedBox(height: 18),
              GlassCard(
                strong: true,
                padding: const EdgeInsets.all(10),
                child: Container(
                  height: 345,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const RadialGradient(
                      center: Alignment(0, -.3),
                      radius: 1.2,
                      colors: [Color(0xFF1B2E50), Color(0xFF0B1222)],
                    ),
                  ),
                  child: _source == null
                      ? _emptyStage()
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ModelViewer(
                            key: ValueKey(_source),
                            src: _source!,
                            alt: _modelName ?? 'Imported 3D model',
                            ar: false,
                            cameraControls: true,
                            autoRotate: true,
                            backgroundColor: AppColors.navyDeep,
                          ),
                        ),
                ),
              ),
              if (_modelName != null) ...[
                const SizedBox(height: 10),
                GlassCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(children: [
                      const Icon(Icons.view_in_ar_outlined,
                          color: AppColors.sky),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_modelName!,
                              style: AppText.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      Text(
                          '${(_modelBytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: AppText.caption),
                    ])),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _loading ? null : _importModel,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file_rounded),
                label:
                    Text(_loading ? 'Preparing model…' : 'Import a 3D model'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: AppText.body.copyWith(color: Colors.redAccent)),
              ],
              const SizedBox(height: 12),
              Text(
                  'Supported format: GLB • Up to 20 MB • Preview runs locally on this device. Importing does not upload the model.',
                  style: AppText.caption),
              const SizedBox(height: 18),
              Text('A focused 3D workflow', style: AppText.h2),
              const SizedBox(height: 10),
              const GlassCard(
                  padding: EdgeInsets.all(15),
                  child: Column(children: [
                    _WorkflowStep(
                        number: '01',
                        title: 'Model',
                        detail:
                            'Create and export a GLB from your 3D software.'),
                    _WorkflowStep(
                        number: '02',
                        title: 'Inspect',
                        detail:
                            'Check silhouette, materials, and lighting from all sides.'),
                    _WorkflowStep(
                        number: '03',
                        title: 'Improve',
                        detail:
                            'Refine the asset and import the next version.'),
                  ])),
            ]),
      );

  Widget _emptyStage() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sky.withValues(alpha: .08),
              border: Border.all(color: AppColors.sky.withValues(alpha: .3)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.blue.withValues(alpha: .18),
                    blurRadius: 32)
              ],
            ),
            child: const Icon(Icons.view_in_ar_rounded,
                color: AppColors.sky, size: 40),
          ),
          const SizedBox(height: 14),
          Text('Your model preview appears here',
              style: AppText.h3, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text('Import a .glb file to get started', style: AppText.caption),
        ]),
      );
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep(
      {required this.number, required this.title, required this.detail});
  final String number, title, detail;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number, style: AppText.label),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.h3.copyWith(fontSize: 14)),
          const SizedBox(height: 3),
          Text(detail, style: AppText.caption)
        ]))
      ]));
}
