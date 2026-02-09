import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/todo/todo_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/courses/course_screen.dart';
import 'settings_screen.dart';
import 'app_link.dart';

class RootShell extends StatefulWidget {
  RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _prefKeyStartTab = 'start_tab_index';

  int _currentIndex = 0;
  bool _loaded = false;

  final ValueNotifier<String?> _todoLink = AppLink.todoToOpen;

  @override
  void initState() {
    super.initState();
    _todoLink.addListener(_onTodoDeepLink);
    _loadStartTab();
  }

  @override
  void dispose() {
    _todoLink.removeListener(_onTodoDeepLink);
    super.dispose();
  }

  void _onTodoDeepLink() {
    final id = _todoLink.value;
    if (id == null) return;

    // Todo 탭으로 이동
    if (mounted) {
      setState(() => _currentIndex = 0);
    }
  }

  Future<void> _loadStartTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefKeyStartTab) ?? 0;

    setState(() {
      _currentIndex = saved.clamp(0, 3);
      _loaded = true;
    });
  }

  Future<void> _setStartTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyStartTab, index);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = [
      TodoScreen(highlightTodoIdListenable: _todoLink),
      const CalendarScreen(),
      const TimetableScreen(),
      const CourseScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final selected = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    currentStartTab: _currentIndex,
                  ),
                ),
              );

              if (selected != null) {
                await _setStartTab(selected);
                setState(() => _currentIndex = selected);
              }
            },
          )
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle), label: 'Todo'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.table_chart), label: 'Timetable'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
        ],
      ),
    );
  }
}
