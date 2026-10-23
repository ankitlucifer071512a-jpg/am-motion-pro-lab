import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppEmojiPickerButton extends StatelessWidget {
  const AppEmojiPickerButton({
    super.key,
    required this.controller,
    this.tooltip = 'Insert emoji',
  });

  final TextEditingController controller;
  final String tooltip;

  Future<void> _open(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.navy,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: EmojiPicker(
              textEditingController: controller,
              onEmojiSelected: (_, __) => Navigator.of(sheetContext).pop(),
              config: const Config(
                height: 300,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: AppColors.navy,
                  emojiSizeMax: 28,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: AppColors.navy,
                  indicatorColor: AppColors.sky,
                  iconColor: AppColors.inkDim,
                  iconColorSelected: AppColors.sky,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: AppColors.navy,
                  buttonColor: AppColors.glassFillStrong,
                  buttonIconColor: AppColors.sky,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: AppColors.navy,
                  buttonIconColor: AppColors.sky,
                  hintText: 'Search emoji',
                ),
              ),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: () => _open(context),
        icon: const Icon(Icons.emoji_emotions_outlined),
      );
}
