import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'course.dart';
import 'course_add_screen.dart';
import 'course_detail_screen.dart';
import 'course_edit_screen.dart';

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key});

  Future<void> _openAdd(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CourseAddScreen()),
    );
  }

  Future<void> _deleteCourse(BuildContext context, Course c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete course?'),
        content: Text(c.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await c.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제 완료')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Course>('courses');

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box<Course> b, _) {
                  final courses = b.values.toList()
                    ..sort((a, c) => a.name.compareTo(c.name));

                  if (courses.isEmpty) {
                    return const Center(
                      child: Text('No courses yet.\nTap + to add your courses.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = courses[i];

                      return ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: Text(c.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(builder: (_) => CourseEditScreen(course: c)),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteCourse(context, c),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseDetailScreen(
                                courseId: c.id,
                                courseName: c.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
