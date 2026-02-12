import 'package:flutter/material.dart';
import '../../app/change_history_service.dart';
import 'course.dart';

class CourseEditScreen extends StatefulWidget {
  final Course course;
  const CourseEditScreen({super.key, required this.course});

  @override
  State<CourseEditScreen> createState() => _CourseEditScreenState();
}

class _CourseEditScreenState extends State<CourseEditScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.course.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    widget.course.name = name;
    await widget.course.save();
    await ChangeHistoryService.log('Course updated', detail: name);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Course')),
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
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}
