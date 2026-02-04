import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/root_shell.dart';
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

  runApp(const CampusMateApp());
}

class CampusMateApp extends StatelessWidget {
  const CampusMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusMate',
      theme: ThemeData(useMaterial3: true),
      home: RootShell(),
    );
  }
}
