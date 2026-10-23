import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'services/idea_lab_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialization = IdeaLabBackend.initialize();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F172A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(AmMotionLabApp(initialization: initialization));
}
