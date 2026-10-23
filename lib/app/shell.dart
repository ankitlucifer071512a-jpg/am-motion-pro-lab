import 'package:flutter/material.dart';

import '../screens/courses/courses_screen.dart';
import '../screens/courses/purchase_courses_screen.dart';
import '../screens/games/game_lab_screen.dart';
import '../screens/idea_lab/idea_lab_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/ambient_background.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/creative_ai_fab.dart';

/// Main app frame: shared background + tab navigation and back history.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final List<int> _history = [];
  final Set<int> _visited = {0}; // tabs are built lazily on first visit

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _history.add(_index);
      _index = i;
      _visited.add(i);
    });
  }

  void _back() {
    if (_index == 0 && _history.isEmpty) return;
    setState(() {
      _index = _history.isEmpty ? 0 : _history.removeLast();
      _visited.add(_index);
    });
  }

  Widget _page(int i) {
    switch (i) {
      case 0:
        return HomeScreen(onNavigate: _go, isActive: _index == 0);
      case 1:
        return const CoursesScreen();
      case 2:
        return const GameLabScreen();
      case 3:
        return const IdeaLabScreen();
      case 4:
        return const PurchaseCoursesScreen();
      case 5:
        return NotificationsScreen(
          onBack: _back,
          onOpenCourses: _openCourseCatalog,
        );
      case 6:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _openCourseCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Courses')),
          body: const AmbientBackground(
            child: SafeArea(child: CoursesScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _index == 0 && _history.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: AmbientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (var i = 0; i < AmBottomNav.items.length; i++)
                        _visited.contains(i)
                            ? _page(i)
                            : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
              const Positioned(right: 18, bottom: 14, child: CreativeAiFab()),
            ],
          ),
        ),
        bottomNavigationBar: AmBottomNav(index: _index, onChanged: _go),
      ),
    );
  }
}
