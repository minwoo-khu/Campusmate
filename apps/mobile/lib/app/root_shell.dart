import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/courses/course_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/todo/todo_screen.dart';
import 'ad_service.dart';
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
  static const _prefKeyLastTab = 'last_tab_index_v1';
  static const _prefKeyStartTabMigratedV2 = 'start_tab_home_migrated_v2';
  static const _prefKeyStartTabExplicit = 'start_tab_explicit_v1';

  static const _homeTab = 0;
  static const _todoTab = 1;
  static const _calendarTab = 2;
  static const _timetableTab = 3;
  static const _coursesTab = 4;

  int _currentIndex = _homeTab;
  int _startTabIndex = _homeTab;
  bool _loaded = false;

  final ValueNotifier<String?> _todoLink = AppLink.todoToOpen;
  BannerAd? _bannerAd;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    _todoLink.addListener(_onTodoDeepLink);
    _loadStartTab();
    _loadBannerAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.I.requestPermissions();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _todoLink.removeListener(_onTodoDeepLink);
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
    await AdService.I.init();
    if (!mounted || !AdService.I.canLoadBanner) return;

    late final BannerAd ad;
    ad = AdService.I.createBannerAd(
      onLoaded: () {
        if (!mounted) {
          ad.dispose();
          return;
        }
        final prev = _bannerAd;
        setState(() {
          _bannerAd = ad;
          _bannerReady = true;
        });
        if (!identical(prev, ad)) {
          prev?.dispose();
        }
      },
      onFailedToLoad: (_) {
        ad.dispose();
        if (!mounted) return;
        setState(() {
          _bannerAd = null;
          _bannerReady = false;
        });
      },
    );
    ad.load();
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
      _setCurrentTab(_todoTab);
    }
  }

  Future<void> _loadStartTab() async {
    final prefs = await SharedPreferences.getInstance();

    var saved = prefs.getInt(_prefKeyStartTab);
    final lastTab = prefs.getInt(_prefKeyLastTab);
    final migrated = prefs.getBool(_prefKeyStartTabMigratedV2) ?? false;
    final explicit = prefs.getBool(_prefKeyStartTabExplicit) ?? false;

    if (!migrated) {
      if (saved != null) {
        saved = (saved + 1).clamp(_todoTab, _coursesTab);
        await prefs.setInt(_prefKeyStartTab, saved);
      } else {
        saved = _homeTab;
      }
      await prefs.setBool(_prefKeyStartTabMigratedV2, true);
    }

    // If user has not explicitly chosen a start tab yet, default to Home.
    if (!explicit) {
      saved = _homeTab;
      await prefs.setInt(_prefKeyStartTab, _homeTab);
    }

    final resolvedStartTab = (saved ?? _homeTab).clamp(_homeTab, _coursesTab);
    final resolvedCurrentTab = (lastTab ?? resolvedStartTab).clamp(
      _homeTab,
      _coursesTab,
    );
    if (lastTab == null) {
      await prefs.setInt(_prefKeyLastTab, resolvedCurrentTab);
    }

    if (!mounted) return;
    setState(() {
      _startTabIndex = resolvedStartTab;
      _currentIndex = resolvedCurrentTab;
      _loaded = true;
    });
  }

  Future<void> _setStartTab(int index, {bool markExplicit = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyStartTab, index);
    if (markExplicit) {
      await prefs.setBool(_prefKeyStartTabExplicit, true);
    }
  }

  Future<void> _persistLastTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLastTab, index);
  }

  void _setCurrentTab(int index) {
    if (!mounted) return;
    final next = index.clamp(_homeTab, _coursesTab);
    if (_currentIndex == next) return;

    setState(() => _currentIndex = next);
    unawaited(_persistLastTab(next));
  }

  Future<void> _openSettings() async {
    final selected = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(currentStartTab: _startTabIndex),
      ),
    );

    if (!mounted) return;
    if (selected != null) {
      await _setStartTab(selected);
      final tab = selected.clamp(_homeTab, _coursesTab);
      if (!mounted) return;
      setState(() {
        _startTabIndex = tab;
        _currentIndex = tab;
      });
      unawaited(_persistLastTab(tab));
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
          _setCurrentTab(index);
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_bannerReady && _bannerAd != null)
            SafeArea(
              top: false,
              bottom: false,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                alignment: Alignment.center,
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
          SafeArea(
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
                      onTap: () => _setCurrentTab(_homeTab),
                      onLongPress: _openSettings,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.check_circle_outline,
                      activeIcon: Icons.check_circle,
                      label: context.tr('할 일', 'Todo'),
                      selected: _currentIndex == _todoTab,
                      onTap: () => _setCurrentTab(_todoTab),
                      onLongPress: _openSettings,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.calendar_month_outlined,
                      activeIcon: Icons.calendar_month,
                      label: context.tr('캘린더', 'Calendar'),
                      selected: _currentIndex == _calendarTab,
                      onTap: () => _setCurrentTab(_calendarTab),
                      onLongPress: _openSettings,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.image_outlined,
                      activeIcon: Icons.image,
                      label: context.tr('시간표', 'Timetable'),
                      selected: _currentIndex == _timetableTab,
                      onTap: () => _setCurrentTab(_timetableTab),
                      onLongPress: _openSettings,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book,
                      label: context.tr('강의', 'Courses'),
                      selected: _currentIndex == _coursesTab,
                      onTap: () => _setCurrentTab(_coursesTab),
                      onLongPress: _openSettings,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
