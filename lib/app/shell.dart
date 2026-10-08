import 'package:flutter/material.dart';

import '../screens/common/placeholder_screen.dart';
import '../screens/courses/courses_screen.dart';
import '../screens/home/home_screen.dart';
import '../widgets/ambient_background.dart';
import '../widgets/bottom_nav.dart';

/// Main app frame: one shared animated background + 5-tab bottom navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final Set<int> _visited = {0}; // tabs are built lazily on first visit

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  Widget _page(int i) {
    switch (i) {
      case 0:
        return HomeScreen(onNavigate: _go);
      case 1:
        return const CoursesScreen();
      case 2:
        return const PlaceholderScreen(
          title: 'My Learning',
          icon: Icons.play_circle_outline_rounded,
          message: 'Your purchased courses, progress and lessons will appear here after login is added.',
        );
      case 3:
        return const PlaceholderScreen(
          title: 'Support',
          icon: Icons.headset_mic_outlined,
          message: 'WhatsApp, phone, email and support tickets are coming in a later phase.',
        );
      default:
        return const PlaceholderScreen(
          title: 'Profile',
          icon: Icons.person_outline_rounded,
          message: 'Profile, certificates and payment history are coming after login is added.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < AmBottomNav.items.length; i++)
                _visited.contains(i) ? _page(i) : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AmBottomNav(index: _index, onChanged: _go),
    );
  }
}
