import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_link.dart';
import 'app/change_history_service.dart';
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
  await HomeWidgetService.syncTodoSummary(Hive.box<TodoItem>('todos').values);

  runApp(const CampusMateApp());
}

class CampusMateApp extends StatefulWidget {
  const CampusMateApp({super.key});

  static _CampusMateAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_CampusMateAppState>();

  @override
  State<CampusMateApp> createState() => _CampusMateAppState();
}

class _CampusMateAppState extends State<CampusMateApp> {
  static const _prefKeyThemeMode = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  StreamSubscription<Uri?>? _widgetLaunchSub;
  String? _lastHandledWidgetUri;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _bindWidgetLaunchEvents();
  }

  @override
  void dispose() {
    _widgetLaunchSub?.cancel();
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefKeyThemeMode) ?? 'system';
    setState(() => _themeMode = _parseThemeMode(value));
  }

  Future<void> _bindWidgetLaunchEvents() async {
    final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    await _handleWidgetLaunch(initial);
    _widgetLaunchSub = HomeWidget.widgetClicked.listen((uri) {
      _handleWidgetLaunch(uri);
    });
  }

  Future<void> _handleWidgetLaunch(Uri? uri) async {
    if (uri == null) return;

    final uriText = uri.toString();
    if (_lastHandledWidgetUri == uriText) return;
    _lastHandledWidgetUri = uriText;

    final todoId = HomeWidgetService.extractCompleteTodoId(uri);
    if (todoId == null) return;

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
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyThemeMode, _themeModeToString(mode));
  }

  ThemeMode get themeMode => _themeMode;

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusMate',
      theme: CampusMateTheme.light(),
      darkTheme: CampusMateTheme.dark(),
      themeMode: _themeMode,
      home: const RootShell(),
    );
  }
}
