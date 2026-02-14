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
  final _nameController = TextEditingController();
  final _memoController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> _sanitizeTags(String raw) {
    final seen = <String>{};
    final out = <String>[];

    final tokens = raw.split(RegExp(r'[,\n]'));
    for (final token in tokens) {
      var tag = token.trim();
      if (tag.isEmpty) continue;
      if (tag.length > SafetyLimits.maxCourseTagChars) {
        tag = tag.substring(0, SafetyLimits.maxCourseTagChars).trim();
      }
      if (tag.isEmpty) continue;
      final key = tag.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(tag);
      if (out.length >= SafetyLimits.maxCourseTagsPerCourse) break;
    }

    return out;
  }

  Future<void> _save() async {
    var name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (name.length > SafetyLimits.maxCourseNameChars) {
      name = name.substring(0, SafetyLimits.maxCourseNameChars);
    }
    var memo = _memoController.text.trim();
    if (memo.length > SafetyLimits.maxCourseMemoChars) {
      memo = memo.substring(0, SafetyLimits.maxCourseMemoChars);
    }
    final tags = _sanitizeTags(_tagsController.text);

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
    await box.add(Course(id: id, name: name, memo: memo, tags: tags));
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
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              maxLength: SafetyLimits.maxCourseNameChars,
              decoration: InputDecoration(
                labelText: context.tr('강의명', 'Course name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              maxLength:
                  SafetyLimits.maxCourseTagsPerCourse *
                  SafetyLimits.maxCourseTagChars,
              decoration: InputDecoration(
                labelText: context.tr('태그', 'Tags'),
                hintText: context.tr(
                  '쉼표로 구분 (예: 전공, 프로젝트)',
                  'Comma separated (ex: major, project)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              maxLength: SafetyLimits.maxCourseMemoChars,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: context.tr('강의 메모', 'Course memo'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cm.navActive,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _save,
          child: Text(context.tr('저장', 'Save')),
        ),
      ),
    );
  }
}
