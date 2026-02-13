import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../app/center_notice.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../app/change_history_service.dart';
import '../../app/safety_limits.dart';
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
    var name = _controller.text.trim();
    if (name.isEmpty) return;
    if (name.length > SafetyLimits.maxCourseNameChars) {
      name = name.substring(0, SafetyLimits.maxCourseNameChars);
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final box = Hive.box<Course>('courses');
    if (box.length >= SafetyLimits.maxCourses) {
      if (!mounted) return;
      CenterNotice.show(
        context,
        message: context.tr(
          '강의 한도(${SafetyLimits.maxCourses}개)에 도달했습니다.',
          'Course limit reached (${SafetyLimits.maxCourses}).',
        ),
        error: true,
      );
      return;
    }
    await box.add(Course(id: id, name: name));
    await ChangeHistoryService.log('Course added', detail: name);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('강의 추가', 'Add Course'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLength: SafetyLimits.maxCourseNameChars,
              decoration: InputDecoration(
                labelText: context.tr('강의명', 'Course name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cm.navActive,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: _save,
                child: Text(context.tr('저장', 'Save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
