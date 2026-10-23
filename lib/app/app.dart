import 'package:flutter/material.dart';

import 'auth_gate.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/brand_appearance.dart';
import '../widgets/brand_intro.dart';
import 'route_observer.dart';

class AmMotionLabApp extends StatefulWidget {
  const AmMotionLabApp({super.key, required this.initialization});

  final Future<void> initialization;

  @override
  State<AmMotionLabApp> createState() => _AmMotionLabAppState();
}

class _AmMotionLabAppState extends State<AmMotionLabApp> {
  @override
  void initState() {
    super.initState();
    BrandAppearance.load().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrandAccent>(
      valueListenable: BrandAppearance.accent,
      builder: (context, accent, _) => MaterialApp(
        title: 'AM Motion Lab',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkWithAccent(accent.primary, accent.secondary),
        navigatorObservers: [appRouteObserver],
        home: BrandIntro(
          initialization: widget.initialization,
          child: AppAuthGate(initialization: widget.initialization),
        ),
      ),
    );
  }
}
