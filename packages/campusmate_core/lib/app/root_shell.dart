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
import 'layout.dart';
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
  static const _prefKeyNotifPrompted = 'notif_permission_prompted_v1';

  static const _homeTab = 0;
  static const _todoTab = 1;
  static const _calendarTab = 2;
  static const _timetableTab = 3;
  static const _coursesTab = 4;
  static const _swipeVelocityThreshold = 240.0;

  int _currentIndex = _homeTab;
  int _startTabIndex = _homeTab;
  bool _loaded = false;

  final ValueNotifier<String?> _todoLink = AppLink.todoToOpen;
  final ValueNotifier<int?> _tabLink = AppLink.tabToOpen;
  final ValueNotifier<int> _todoUiResetEpoch = ValueNotifier<int>(0);
  BannerAd? _bannerAd;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    _todoLink.addListener(_onTodoDeepLink);
    _tabLink.addListener(_onTabDeepLink);
    _loadStartTab();
    _loadBannerAd();
    _scheduleNotificationPermissionPrompt();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _todoLink.removeListener(_onTodoDeepLink);
    _tabLink.removeListener(_onTabDeepLink);
    _todoUiResetEpoch.dispose();
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

  void _scheduleNotificationPermissionPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_promptNotificationPermissionIfNeeded());
    });
  }

  Future<void> _promptNotificationPermissionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_prefKeyNotifPrompted) ?? false;
    if (alreadyPrompted || !mounted) return;

    try {
      await NotificationService.I.requestPermissions();
      await prefs.setBool(_prefKeyNotifPrompted, true);
    } catch (_) {
      // Retry on next launch if prompt request failed unexpectedly.
    }
  }

  void _onTodoDeepLink() {
    final id = _todoLink.value;
    if (id == null) return;

    if (mounted) {
      _setCurrentTab(_todoTab);
    }
  }

  void _onTabDeepLink() {
    final index = _tabLink.value;
    if (index == null) return;
    if (mounted) {
      _setCurrentTab(index);
    }
    AppLink.clearTab();
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

    if (_currentIndex == _todoTab && next != _todoTab) {
      _todoUiResetEpoch.value++;
    }

    setState(() => _currentIndex = next);
    unawaited(_persistLastTab(next));
  }

  void _onBodyHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null || velocity.abs() < _swipeVelocityThreshold) return;

    final direction = velocity < 0 ? 1 : -1;
    _setCurrentTab(_currentIndex + direction);
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

  Widget _buildBannerStrip({double bottomMargin = 8}) {
    if (!_bannerReady || _bannerAd == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        alignment: Alignment.center,
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }

  List<_ShellNavEntry> _navItems(BuildContext context) {
    return [
      _ShellNavEntry(
        index: _homeTab,
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: context.tr('홈', 'Home'),
      ),
      _ShellNavEntry(
        index: _todoTab,
        icon: Icons.check_circle_outline,
        activeIcon: Icons.check_circle,
        label: context.tr('할 일', 'Todo'),
      ),
      _ShellNavEntry(
        index: _calendarTab,
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        label: context.tr('캘린더', 'Calendar'),
      ),
      _ShellNavEntry(
        index: _timetableTab,
        icon: Icons.image_outlined,
        activeIcon: Icons.image,
        label: context.tr('시간표', 'Timetable'),
      ),
      _ShellNavEntry(
        index: _coursesTab,
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: context.tr('강의', 'Courses'),
      ),
    ];
  }

  Widget _buildMobileBottomNav(
    CampusMateColors cm,
    List<_ShellNavEntry> navItems,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBannerStrip(),
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
              children: navItems
                  .map(
                    (item) => Expanded(
                      child: _NavItem(
                        icon: item.icon,
                        activeIcon: item.activeIcon,
                        label: item.label,
                        selected: _currentIndex == item.index,
                        onTap: () => _setCurrentTab(item.index),
                        onLongPress: _openSettings,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar(
    CampusMateColors cm,
    List<_ShellNavEntry> navItems,
  ) {
    return SafeArea(
      right: false,
      child: Container(
        width: 220,
        margin: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: cm.navBarBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cm.cardBorder),
          boxShadow: [
            BoxShadow(
              color: cm.navBarShadow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CampusMate',
                  style: TextStyle(
                    color: cm.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            for (final item in navItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _SidebarNavItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  selected: _currentIndex == item.index,
                  onTap: () => _setCurrentTab(item.index),
                  onLongPress: _openSettings,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cm = context.cmColors;
    final desktopSidebarLayout = isDesktopLayout(context, minWidth: 1080);
    final navItems = _navItems(context);

    final tabs = [
      HomeScreen(onOpenSettings: _openSettings),
      TodoScreen(
        highlightTodoIdListenable: _todoLink,
        resetUiListenable: _todoUiResetEpoch,
      ),
      const CalendarScreen(),
      const TimetableScreen(),
      const CourseScreen(),
    ];

    final tabStack = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      onHorizontalDragEnd: desktopSidebarLayout
          ? null
          : _onBodyHorizontalDragEnd,
      child: IndexedStack(index: _currentIndex, children: tabs),
    );

    return Scaffold(
      backgroundColor: cm.scaffoldBg,
      body: desktopSidebarLayout
          ? Row(
              children: [
                _buildDesktopSidebar(cm, navItems),
                Expanded(child: tabStack),
              ],
            )
          : tabStack,
      bottomNavigationBar: desktopSidebarLayout
          ? (_bannerReady && _bannerAd != null ? _buildBannerStrip() : null)
          : _buildMobileBottomNav(cm, navItems),
    );
  }
}

class _ShellNavEntry {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _ShellNavEntry({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
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

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SidebarNavItem({
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

    return Material(
      color: selected ? cm.inputBg : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
