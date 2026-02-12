import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/courses/course_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/todo/todo_screen.dart';
import 'app_link.dart';
import 'home_screen.dart';
import 'l10n.dart';
import 'notification_service.dart';
import 'settings_screen.dart';
import 'theme.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _prefKeyStartTab = 'start_tab_index';
  static const _prefKeyStartTabMigratedV2 = 'start_tab_home_migrated_v2';

  static const _homeTab = 0;
  static const _todoTab = 1;
  static const _calendarTab = 2;
  static const _timetableTab = 3;
  static const _coursesTab = 4;

  int _currentIndex = _homeTab;
  bool _loaded = false;

  final ValueNotifier<String?> _todoLink = AppLink.todoToOpen;

  @override
  void initState() {
    super.initState();
    _todoLink.addListener(_onTodoDeepLink);
    _loadStartTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.I.requestPermissions();
    });
  }

  @override
  void dispose() {
    _todoLink.removeListener(_onTodoDeepLink);
    super.dispose();
  }

  void _dismissKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null) {
      focus.unfocus();
    }
  }

  void _onTodoDeepLink() {
    final id = _todoLink.value;
    if (id == null) return;

    if (mounted) {
      setState(() => _currentIndex = _todoTab);
    }
  }

  Future<void> _loadStartTab() async {
    final prefs = await SharedPreferences.getInstance();

    var saved = prefs.getInt(_prefKeyStartTab);
    final migrated = prefs.getBool(_prefKeyStartTabMigratedV2) ?? false;

    if (!migrated) {
      if (saved != null) {
        saved = (saved + 1).clamp(_todoTab, _coursesTab);
        await prefs.setInt(_prefKeyStartTab, saved);
      } else {
        saved = _homeTab;
      }
      await prefs.setBool(_prefKeyStartTabMigratedV2, true);
    }

    setState(() {
      _currentIndex = (saved ?? _homeTab).clamp(_homeTab, _coursesTab);
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
      setState(() => _currentIndex = selected.clamp(_homeTab, _coursesTab));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cm = context.cmColors;

    final tabs = [
      HomeScreen(
        onOpenSettings: _openSettings,
        onNavigateToTab: (index) {
          setState(() => _currentIndex = index.clamp(_homeTab, _coursesTab));
        },
      ),
      TodoScreen(highlightTodoIdListenable: _todoLink),
      const CalendarScreen(),
      const TimetableScreen(),
      const CourseScreen(),
    ];

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: IndexedStack(index: _currentIndex, children: tabs),
      ),
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
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: context.tr('홈', 'Home'),
                  selected: _currentIndex == _homeTab,
                  onTap: () => setState(() => _currentIndex = _homeTab),
                  onLongPress: _openSettings,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.check_circle_outline,
                  activeIcon: Icons.check_circle,
                  label: context.tr('할 일', 'Todo'),
                  selected: _currentIndex == _todoTab,
                  onTap: () => setState(() => _currentIndex = _todoTab),
                  onLongPress: _openSettings,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month,
                  label: context.tr('캘린더', 'Calendar'),
                  selected: _currentIndex == _calendarTab,
                  onTap: () => setState(() => _currentIndex = _calendarTab),
                  onLongPress: _openSettings,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.image_outlined,
                  activeIcon: Icons.image,
                  label: context.tr('시간표', 'Timetable'),
                  selected: _currentIndex == _timetableTab,
                  onTap: () => setState(() => _currentIndex = _timetableTab),
                  onLongPress: _openSettings,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book,
                  label: context.tr('강의', 'Courses'),
                  selected: _currentIndex == _coursesTab,
                  onTap: () => setState(() => _currentIndex = _coursesTab),
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
