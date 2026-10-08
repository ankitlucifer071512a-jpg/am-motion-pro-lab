import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'shell.dart';

class AmMotionLabApp extends StatelessWidget {
  const AmMotionLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AM Motion Lab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
