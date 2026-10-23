import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

enum BrandAccent {
  motionBlue('Motion Blue', AppColors.blue, AppColors.violet),
  electricPurple('Electric Purple', AppColors.violet, AppColors.blue),
  iceBlue('Ice Blue', AppColors.sky, AppColors.blue);

  const BrandAccent(this.label, this.primary, this.secondary);
  final String label;
  final Color primary;
  final Color secondary;
}

/// Small persisted accent adjustment. The app remains in its dark brand theme.
class BrandAppearance {
  BrandAppearance._();

  static const _key = 'am_motion_brand_accent';
  static final ValueNotifier<BrandAccent> accent = ValueNotifier(BrandAccent.motionBlue);

  static Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    accent.value = BrandAccent.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => BrandAccent.motionBlue,
    );
  }

  static Future<void> select(BrandAccent value) async {
    accent.value = value;
    await (await SharedPreferences.getInstance()).setString(_key, value.name);
  }
}
