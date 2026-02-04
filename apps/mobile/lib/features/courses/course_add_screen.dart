import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'course.dart';

class CourseAddScreen extends StatefulWidget {
  const CourseAddScreen({super.key});

  @override
  State<CourseAddScreen> createState() => _CourseAddScreenState();
}

class _CourseAddScreenState extends State<CourseAddScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final box = Hive.box<Course>('courses');
    await box.add(Course(id: id, name: name));

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Course')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Course name',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
