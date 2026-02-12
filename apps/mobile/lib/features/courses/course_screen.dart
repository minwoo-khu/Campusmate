import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'course.dart';
import 'course_add_screen.dart';
import 'course_detail_screen.dart';
import 'course_edit_screen.dart';
import 'course_material.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAdd(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CourseAddScreen()));
  }

  Future<void> _openEdit(BuildContext context, Course course) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CourseEditScreen(course: course)),
    );
  }

  Future<void> _deleteCourse(BuildContext context, Course course) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('강의를 삭제할까요?'),
        content: Text(course.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await course.delete();
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('강의가 삭제되었습니다.')));
  }

  int _countPageMemosForCourse(
    Course course,
    List<CourseMaterial> materials,
    Box<String> pageMemoBox,
  ) {
    var total = 0;

    for (final material in materials.where((m) => m.courseId == course.id)) {
      final key = material.key;
      if (key is! int) continue;

      final raw = pageMemoBox.get('m:$key:pages');
      if (raw == null || raw.trim().isEmpty) continue;

      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          total += parsed.length;
        }
      } catch (_) {
        // Ignore malformed memo data.
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final courseBox = Hive.box<Course>('courses');
    final materialBox = Hive.box<CourseMaterial>('course_materials');
    final pageMemoBox = Hive.box<String>('material_page_memos');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              courseBox.listenable(),
              materialBox.listenable(),
              pageMemoBox.listenable(),
              _searchController,
            ]),
            builder: (context, _) {
              final query = _searchController.text.trim().toLowerCase();

              final courses = courseBox.values.toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              final materials = materialBox.values.toList();

              final filtered = query.isEmpty
                  ? courses
                  : courses
                        .where((c) => c.name.toLowerCase().contains(query))
                        .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '내 강의',
                        style: TextStyle(
                          fontSize: 42 / 1.25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _openAdd(context),
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFE8EEF9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '과목명 또는 메모 검색...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFEAECEF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('표시할 강의가 없습니다.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 18),
                            itemCount: filtered.length + 1,
                            itemBuilder: (_, i) {
                              if (i == filtered.length) {
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDEE8F8),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PDF 학습 기능',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        '강의자료를 열어 페이지 단위로 메모를 남기고 태그로 필터링할 수 있습니다.',
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final course = filtered[i];
                              final pdfCount = materials
                                  .where((m) => m.courseId == course.id)
                                  .length;
                              final memoCount = _countPageMemosForCourse(
                                course,
                                materials,
                                pageMemoBox,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CourseDetailScreen(
                                          courseId: course.id,
                                          courseName: course.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    course.name,
                                                    style: const TextStyle(
                                                      fontSize: 28 / 1.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'Course materials',
                                                    style: TextStyle(
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<_CourseMenu>(
                                              icon: const Icon(
                                                Icons.more_horiz,
                                                color: Color(0xFF94A3B8),
                                              ),
                                              onSelected: (value) async {
                                                if (value == _CourseMenu.edit) {
                                                  await _openEdit(
                                                    context,
                                                    course,
                                                  );
                                                } else if (value ==
                                                    _CourseMenu.delete) {
                                                  await _deleteCourse(
                                                    context,
                                                    course,
                                                  );
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: _CourseMenu.edit,
                                                  child: Text('수정'),
                                                ),
                                                PopupMenuItem(
                                                  value: _CourseMenu.delete,
                                                  child: Text('삭제'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3E8FF),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '강의자료 $pdfCount',
                                                style: const TextStyle(
                                                  color: Color(0xFF7E22CE),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEDD5),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '페이지 메모 $memoCount',
                                                style: const TextStyle(
                                                  color: Color(0xFFEA580C),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _CourseMenu { edit, delete }
