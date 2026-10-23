import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../core/theme/app_colors.dart';

/// Shared interactive GLB viewer with visible loading and model-error states.
class InteractiveModelViewer extends StatelessWidget {
  const InteractiveModelViewer({
    super.key,
    required this.src,
    required this.alt,
    this.poster,
    this.autoRotate = true,
    this.backgroundColor = AppColors.navyDeep,
  });

  final String src;
  final String alt;
  final String? poster;
  final bool autoRotate;
  final Color backgroundColor;

  static const _css = r'''
    .am-model-status {
      position: absolute; z-index: 10; left: 12px; right: 12px; bottom: 12px;
      box-sizing: border-box; padding: 9px 12px; border-radius: 10px;
      background: rgba(9, 14, 26, .9); color: #E7ECF5;
      border: 1px solid rgba(148, 173, 214, .36);
      font: 13px sans-serif; text-align: center; pointer-events: none;
    }
    .am-model-status[data-error="true"] { color: #FFD7D7; border-color: #B65F70; }
  ''';

  static const _js = r'''
    (() => {
      const viewer = document.querySelector('model-viewer');
      if (!viewer) return;
      const status = document.createElement('div');
      status.className = 'am-model-status';
      status.setAttribute('role', 'status');
      status.setAttribute('aria-live', 'polite');
      status.textContent = 'Preparing 3D preview…';
      document.body.appendChild(status);
      viewer.addEventListener('progress', (event) => {
        const amount = Math.round((event.detail?.totalProgress || 0) * 100);
        status.dataset.error = 'false';
        status.textContent = `Loading model ${amount}%`;
      });
      viewer.addEventListener('load', () => status.remove());
      viewer.addEventListener('error', () => {
        status.dataset.error = 'true';
        status.textContent = 'Could not load this model. Check the GLB and pack its textures into the file.';
      });
    })();
  ''';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // model-viewer allocates a WebGL framebuffer from its host size.
      // Do not create that platform view until it has real, non-zero bounds.
      if (!constraints.hasBoundedWidth ||
          !constraints.hasBoundedHeight ||
          constraints.maxWidth <= 0 ||
          constraints.maxHeight <= 0) {
        return ColoredBox(color: backgroundColor);
      }
      return SizedBox.expand(
        child: ModelViewer(
          src: src,
          alt: alt,
          poster: poster,
          loading: Loading.eager,
          cameraControls: true,
          autoRotate: autoRotate,
          backgroundColor: backgroundColor,
          debugLogging: false,
          relatedCss: _css,
          relatedJs: _js,
        ),
      );
    },
  );
}
