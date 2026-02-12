import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/change_history_service.dart';
import 'app/home_widget_service.dart';
import 'app/root_shell.dart';
import 'app/notification_service.dart';
import 'features/todo/todo_model.dart';
import 'features/courses/course_material.dart';
import 'features/courses/course.dart';

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

class CampusMateApp extends StatelessWidget {
  const CampusMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    const appleBg = Color(0xFFF5F5F7);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'CampusMate',
      theme: base.copyWith(
        scaffoldBackgroundColor: appleBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: appleBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 28,
            letterSpacing: -0.4,
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return Colors.white;
          }),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
          secondaryLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          checkmarkColor: Colors.white,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB)),
      ),
      home: RootShell(),
    );
  }
}
