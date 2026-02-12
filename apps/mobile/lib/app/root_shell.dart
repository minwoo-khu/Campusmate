import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/courses/course_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/todo/todo_screen.dart';
import 'app_link.dart';
import 'l10n.dart';
import 'settings_screen.dart';
import 'theme.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

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

  Future<void> _openSettings() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(currentStartTab: _currentIndex),
      ),
    );

    if (selected != null) {
      await _setStartTab(selected);
      setState(() => _currentIndex = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cm = context.cmColors;

    final tabs = [
      TodoScreen(highlightTodoIdListenable: _todoLink),
      const CalendarScreen(),
      const TimetableScreen(),
      const CourseScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: cm.navBarBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: cm.navBarShadow,
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.check_circle_outline,
                  activeIcon: Icons.check_circle,
                  label: context.tr('할 일', 'Todo'),
                  selected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                  onLongPress: _openSettings,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month,
                  label: context.tr('캘린더', 'Calendar'),
                  selected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                  onLongPress: _openSettings,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.image_outlined,
                  activeIcon: Icons.image,
                  label: context.tr('시간표', 'Timetable'),
                  selected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                  onLongPress: _openSettings,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book,
                  label: context.tr('강의', 'Courses'),
                  selected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                  onLongPress: _openSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final color = selected ? cm.navActive : cm.navInactive;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
