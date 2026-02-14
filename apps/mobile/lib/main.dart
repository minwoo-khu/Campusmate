import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/ad_service.dart';
import 'app/app_link.dart';
import 'app/change_history_service.dart';
import 'app/crash_reporting_service.dart';
import 'app/home_widget_service.dart';
import 'app/notification_service.dart';
import 'app/root_shell.dart';
import 'app/theme.dart';
import 'features/courses/course_material.dart';
import 'features/courses/course.dart';
import 'features/todo/todo_model.dart';
import 'features/todo/todo_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(TodoItemAdapter());
  Hive.registerAdapter(CourseAdapter());
  Hive.registerAdapter(CourseMaterialAdapter());

  await Hive.openBox<TodoItem>('todos');
  await Hive.openBox<Course>('courses');
  await Hive.openBox<CourseMaterial>('course_materials');
  await Hive.openBox<String>('material_notes');
  await Hive.openBox<String>('material_page_memos');
  await Hive.openBox<String>(ChangeHistoryService.boxName);

  await Hive.openBox<int>('notif');
  await NotificationService.I.init();
  await HomeWidgetService.syncLocaleCode('ko');
  await HomeWidgetService.syncTodoSummary(Hive.box<TodoItem>('todos').values);
  await HomeWidgetService.syncTimetableSummary(
    Hive.box<Course>('courses').values,
  );
  await AdService.I.init();

  await CrashReportingService.I.runAppWithReporting(const CampusMateApp());
}

abstract class CampusMateAppController {
  ThemeMode get themeMode;
  String get themePresetKey;
  CampusMateCustomPalette get customThemePalette;
  String get localeCode;
  Future<void> setThemeMode(ThemeMode mode);
  Future<void> setThemePresetKey(String key);
  Future<void> setCustomThemePalette(CampusMateCustomPalette palette);
  Future<void> setLocaleCode(String code);
}

class CampusMateApp extends StatefulWidget {
  const CampusMateApp({super.key});

  static CampusMateAppController? of(BuildContext context) =>
      context.findAncestorStateOfType<_CampusMateAppState>();

  @override
  State<CampusMateApp> createState() => _CampusMateAppState();
}

class _CampusMateAppState extends State<CampusMateApp>
    implements CampusMateAppController {
  static const _prefKeyThemeMode = 'theme_mode';
  static const _prefKeyThemePreset = 'theme_preset_key';
  static const _prefKeyThemeCustomPalette = 'theme_custom_palette_v1';
  static const _prefKeyLocaleCode = 'locale_code';

  ThemeMode _themeMode = ThemeMode.system;
  String _themePresetKey = CampusMateTheme.defaultPaletteKey;
  CampusMateCustomPalette _customThemePalette =
      CampusMateCustomPalette.defaults;
  Locale _locale = const Locale('ko');
  StreamSubscription<Uri?>? _widgetLaunchSub;
  StreamSubscription<BoxEvent>? _courseBoxSub;
  Timer? _courseWidgetSyncDebounce;
  String? _lastHandledWidgetUri;
  DateTime? _lastHandledWidgetUriAt;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadThemePresetKey();
    _loadThemeCustomPalette();
    _loadLocaleCode();
    _bindWidgetLaunchEvents();
    _bindCourseWidgetSync();
  }

  @override
  void dispose() {
    _widgetLaunchSub?.cancel();
    _courseBoxSub?.cancel();
    _courseWidgetSyncDebounce?.cancel();
    super.dispose();
  }

  void _bindCourseWidgetSync() {
    final courseBox = Hive.box<Course>('courses');
    _courseBoxSub = courseBox.watch().listen((_) {
      _courseWidgetSyncDebounce?.cancel();
      _courseWidgetSyncDebounce = Timer(const Duration(milliseconds: 250), () {
        unawaited(HomeWidgetService.syncTimetableSummary(courseBox.values));
      });
    });
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefKeyThemeMode) ?? 'system';
    if (!mounted) return;
    setState(() => _themeMode = _parseThemeMode(value));
  }

  Future<void> _loadThemePresetKey() async {
    final prefs = await SharedPreferences.getInstance();
    final value =
        prefs.getString(_prefKeyThemePreset) ??
        CampusMateTheme.defaultPaletteKey;
    final normalized = CampusMateTheme.isValidPaletteKey(value)
        ? value
        : CampusMateTheme.defaultPaletteKey;
    if (!mounted) return;
    setState(() => _themePresetKey = normalized);
  }

  Future<void> _loadThemeCustomPalette() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeyThemeCustomPalette);
    var parsed = CampusMateCustomPalette.defaults;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          parsed = CampusMateCustomPalette.fromStorageMap(decoded);
        }
      } catch (_) {
        parsed = CampusMateCustomPalette.defaults;
      }
    }
    if (!mounted) return;
    setState(() => _customThemePalette = parsed);
  }

  Future<void> _loadLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKeyLocaleCode) ?? 'ko';
    final locale = _parseLocale(code);
    unawaited(HomeWidgetService.syncLocaleCode(locale.languageCode));
    if (!mounted) return;
    setState(() => _locale = locale);
  }

  Future<void> _bindWidgetLaunchEvents() async {
    try {
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      await _handleWidgetLaunch(initial);
      _widgetLaunchSub = HomeWidget.widgetClicked.listen((uri) {
        _handleWidgetLaunch(uri);
      });
    } on MissingPluginException {
      // Widget host channel can be unavailable on some builds/dev sessions.
      if (kDebugMode) {
        debugPrint(
          'home_widget plugin not available; widget launch bind skipped',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('home_widget bind failed: $e');
      }
    }
  }

  Future<void> _handleWidgetLaunch(Uri? uri) async {
    if (uri == null) return;

    final uriText = uri.toString();
    final now = DateTime.now();
    if (_lastHandledWidgetUri == uriText &&
        _lastHandledWidgetUriAt != null &&
        now.difference(_lastHandledWidgetUriAt!) <
            const Duration(milliseconds: 900)) {
      return;
    }
    _lastHandledWidgetUri = uriText;
    _lastHandledWidgetUriAt = now;

    final todoId = HomeWidgetService.extractCompleteTodoId(uri);
    if (todoId != null) {
      final box = Hive.box<TodoItem>('todos');
      TodoItem? target;
      for (final item in box.values) {
        if (item.id == todoId) {
          target = item;
          break;
        }
      }
      if (target == null) return;

      if (!target.completed) {
        await todoRepo.toggle(target);
      }
      AppLink.openTodo(target.id);
      return;
    }

    final tabToOpen = HomeWidgetService.extractTabToOpen(uri);
    if (tabToOpen != null) {
      AppLink.openTab(tabToOpen);
    }
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyThemeMode, _themeModeToString(mode));
  }

  @override
  Future<void> setThemePresetKey(String key) async {
    final normalized = CampusMateTheme.isValidPaletteKey(key)
        ? key
        : CampusMateTheme.defaultPaletteKey;
    setState(() => _themePresetKey = normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyThemePreset, normalized);
  }

  @override
  Future<void> setCustomThemePalette(CampusMateCustomPalette palette) async {
    setState(() => _customThemePalette = palette);
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(palette.toStorageMap());
    await prefs.setString(_prefKeyThemeCustomPalette, encoded);
  }

  @override
  Future<void> setLocaleCode(String code) async {
    final locale = _parseLocale(code);
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLocaleCode, locale.languageCode);
    await HomeWidgetService.syncLocaleCode(locale.languageCode);
    await HomeWidgetService.syncTodoSummary(Hive.box<TodoItem>('todos').values);
    await HomeWidgetService.syncTimetableSummary(
      Hive.box<Course>('courses').values,
    );
  }

  @override
  ThemeMode get themeMode => _themeMode;
  @override
  String get themePresetKey => _themePresetKey;
  @override
  CampusMateCustomPalette get customThemePalette => _customThemePalette;
  @override
  String get localeCode => _locale.languageCode;

  static ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static Locale _parseLocale(String code) {
    if (code.toLowerCase().startsWith('en')) return const Locale('en');
    return const Locale('ko');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusMate',
      theme: CampusMateTheme.light(
        paletteKey: _themePresetKey,
        customPalette: _customThemePalette,
      ),
      darkTheme: CampusMateTheme.dark(
        paletteKey: _themePresetKey,
        customPalette: _customThemePalette,
      ),
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootShell(),
    );
  }
}
