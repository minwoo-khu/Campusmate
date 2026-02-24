import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/change_history_service.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../todo/todo_model.dart';
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

  String _t(String ko, String en) => context.tr(ko, en);

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

  String _courseSearchBlob({
    required Course course,
    required List<CourseMaterial> materials,
    required Box<String> noteBox,
    required Box<String> pageMemoBox,
  }) {
    final parts = <String>[course.name];
    final courseMemo = course.memo.trim();
    if (courseMemo.isNotEmpty) {
      parts.add(courseMemo);
    }
    if (course.tags.isNotEmpty) {
      parts.addAll(course.tags);
    }

    final courseMaterials = materials.where((m) => m.courseId == course.id);
    for (final material in courseMaterials) {
      parts.add(material.fileName);

      final key = material.key;
      if (key is! int) continue;

      final overallNote = noteBox.get('m:$key');
      if (overallNote != null && overallNote.trim().isNotEmpty) {
        parts.add(overallNote);
      }

      final pageRaw = pageMemoBox.get('m:$key:pages');
      if (pageRaw == null || pageRaw.trim().isEmpty) continue;

      try {
        final parsed = jsonDecode(pageRaw);
        if (parsed is! Map<String, dynamic>) continue;

        for (final entry in parsed.entries) {
          final value = entry.value;
          if (value is String) {
            parts.add(value);
            continue;
          }
          if (value is Map<String, dynamic>) {
            final text = value['text'];
            if (text is String && text.trim().isNotEmpty) {
              parts.add(text);
            }

            final tags = value['tags'];
            if (tags is List) {
              for (final t in tags) {
                if (t is String && t.trim().isNotEmpty) {
                  parts.add(t);
                }
              }
            }
          }
        }
      } catch (_) {
        // Ignore malformed memo payload.
      }
    }

    return parts.join(' ').toLowerCase();
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
        // Ignore malformed payload.
      }
    }

    return total;
  }

  int _countLinkedTodosForNext7Days(Course course, List<TodoItem> todos) {
    final name = course.name.trim().toLowerCase();
    if (name.isEmpty) return 0;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 7));

    return todos.where((todo) {
      if (todo.completed) return false;
      final due = todo.dueAt;
      if (due == null) return false;
      if (due.isBefore(start) || !due.isBefore(end)) return false;
      return todo.title.toLowerCase().contains(name);
    }).length;
  }

  String? _latestMaterialTitleForCourse(
    Course course,
    List<CourseMaterial> materials,
  ) {
    final courseMaterials =
        materials.where((m) => m.courseId == course.id).toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    if (courseMaterials.isEmpty) return null;
    return courseMaterials.first.fileName;
  }

  String? _latestMemoPreviewForCourse(
    Course course,
    List<CourseMaterial> materials,
    Box<String> noteBox,
    Box<String> pageMemoBox,
  ) {
    final courseMemo = course.memo.trim();
    if (courseMemo.isNotEmpty) return courseMemo;

    final courseMaterials =
        materials.where((m) => m.courseId == course.id).toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    for (final material in courseMaterials) {
      final key = material.key;
      if (key is! int) continue;

      final note = noteBox.get('m:$key')?.trim();
      if (note != null && note.isNotEmpty) {
        return note;
      }

      final raw = pageMemoBox.get('m:$key:pages');
      if (raw == null || raw.trim().isEmpty) continue;

      try {
        final parsed = jsonDecode(raw);
        if (parsed is! Map<String, dynamic>) continue;

        final pageEntries = parsed.entries.toList()
          ..sort((a, b) {
            final ap = int.tryParse(a.key) ?? 0;
            final bp = int.tryParse(b.key) ?? 0;
            return ap.compareTo(bp);
          });

        for (final entry in pageEntries) {
          final value = entry.value;
          if (value is String) {
            final text = value.trim();
            if (text.isNotEmpty) return text;
            continue;
          }
          if (value is Map<String, dynamic>) {
            final text = (value['text'] as String?)?.trim() ?? '';
            if (text.isNotEmpty) return text;
          }
        }
      } catch (_) {
        // Ignore malformed memo payload.
      }
    }

    return null;
  }

  String _trimPreview(String text, {int max = 64}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  Future<void> _deleteCourse(BuildContext context, Course course) async {
    final cm = context.cmColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('강의를 삭제할까요?', 'Delete course?')),
        content: Text(course.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('취소', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cm.deleteBg,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('삭제', 'Delete')),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final materialBox = Hive.box<CourseMaterial>('course_materials');
    final noteBox = Hive.box<String>('material_notes');
    final pageMemoBox = Hive.box<String>('material_page_memos');
    final linkedMaterials = materialBox.values
        .where((m) => m.courseId == course.id)
        .toList();

    for (final material in linkedMaterials) {
      final key = material.key;
      if (key is int) {
        await noteBox.delete('m:$key');
        await pageMemoBox.delete('m:$key:pages');
      }

      final file = File(material.localPath);
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore local file cleanup failures.
      }

      await material.delete();
    }

    final deletedName = course.name;
    await course.delete();
    final deletedPdfCount = linkedMaterials.length;
    await ChangeHistoryService.log(
      'Course deleted',
      detail: deletedPdfCount > 0
          ? '$deletedName (+$deletedPdfCount PDFs)'
          : deletedName,
    );
  }

  Widget _buildFirstCourseEmptyState(BuildContext context) {
    final cm = context.cmColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 64, 0, 24),
      children: [
        Icon(Icons.school_outlined, size: 54, color: cm.checkInactive),
        const SizedBox(height: 14),
        Text(
          _t('아직 등록된 강의가 없어요.', 'No courses yet.'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: cm.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            '첫 강의를 추가하면 PDF/메모를 과목별로 정리할 수 있어요.',
            'Add your first course to organize PDFs and notes.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: cm.textTertiary, height: 1.4),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FilledButton.icon(
            onPressed: () => _openAdd(context),
            style: FilledButton.styleFrom(
              backgroundColor: cm.navActive,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: Text(_t('첫 강의 추가', 'Add first course')),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final courseBox = Hive.box<Course>('courses');
    final materialBox = Hive.box<CourseMaterial>('course_materials');
    final noteBox = Hive.box<String>('material_notes');
    final pageMemoBox = Hive.box<String>('material_page_memos');
    final todoBox = Hive.box<TodoItem>('todos');

    return Scaffold(
      backgroundColor: cm.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              courseBox.listenable(),
              materialBox.listenable(),
              noteBox.listenable(),
              pageMemoBox.listenable(),
              todoBox.listenable(),
              _searchController,
            ]),
            builder: (context, _) {
              final query = _searchController.text.trim().toLowerCase();

              final courses = courseBox.values.toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              final materials = materialBox.values.toList();
              final todos = todoBox.values.toList();

              final filtered = query.isEmpty
                  ? courses
                  : courses
                        .where(
                          (c) => _courseSearchBlob(
                            course: c,
                            materials: materials,
                            noteBox: noteBox,
                            pageMemoBox: pageMemoBox,
                          ).contains(query),
                        )
                        .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _t('내 강의', 'Courses'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: cm.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _t('최근 변경', 'Recent changes'),
                        onPressed: null,
                        icon: const SizedBox.shrink(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 0),
                      IconButton(
                        onPressed: () => _openAdd(context),
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          backgroundColor: cm.iconButtonBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _t(
                        '강의명, PDF 이름, 메모, 태그 검색...',
                        'Search course, PDF name, note text, tag...',
                      ),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: cm.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (query.isEmpty && courses.isNotEmpty) ...[
                    Text(
                      _t('강의 대시보드', 'Course dashboard'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cm.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 138,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: courses.length,
                        separatorBuilder: (_, separatorIndex) =>
                            const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final course = courses[i];
                          final linkedTodos = _countLinkedTodosForNext7Days(
                            course,
                            todos,
                          );
                          final latestMaterial = _latestMaterialTitleForCourse(
                            course,
                            materials,
                          );
                          final latestMemo = _latestMemoPreviewForCourse(
                            course,
                            materials,
                            noteBox,
                            pageMemoBox,
                          );

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
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
                              width: 260,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cm.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cm.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: cm.textPrimary,
                                    ),
                                  ),
                                  if (course.tags.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: course.tags.take(4).map((tag) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cm.inputBg,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: cm.cardBorder,
                                            ),
                                          ),
                                          child: Text(
                                            '#$tag',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: cm.textSecondary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    _t(
                                      '연결된 할 일(7일): $linkedTodos',
                                      'Linked todos (7d): $linkedTodos',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cm.navActive,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _t(
                                      '최근 PDF: ${latestMaterial ?? '없음'}',
                                      'Latest PDF: ${latestMaterial ?? 'No PDF yet'}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cm.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _t(
                                      '최근 메모: ${latestMemo == null ? '없음' : _trimPreview(latestMemo)}',
                                      'Recent memo: ${latestMemo == null ? 'No memo yet' : _trimPreview(latestMemo)}',
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cm.textTertiary,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: filtered.isEmpty
                        ? (query.isEmpty && courses.isEmpty
                              ? _buildFirstCourseEmptyState(context)
                              : ListView(
                                  children: [
                                    const SizedBox(height: 120),
                                    Center(
                                      child: Text(
                                        _t(
                                          '검색 조건에 맞는 강의가 없어요.',
                                          'No matching course found.',
                                        ),
                                        style: TextStyle(
                                          color: cm.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 18),
                            itemCount: filtered.length + 1,
                            itemBuilder: (_, i) {
                              if (i == filtered.length) {
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cm.tipBannerBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cm.tipBannerBorder,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('PDF 학습 모드', 'PDF learning mode'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: cm.tipBannerTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _t(
                                          '자료를 열어 페이지 단위 메모/태그를 남겨 보세요. 검색에서 메모까지 찾을 수 있습니다.',
                                          'Open materials and attach page-level notes/tags. Search now supports these notes.',
                                        ),
                                        style: TextStyle(
                                          color: cm.tipBannerBody,
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
                                      color: cm.cardBg,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: cm.cardBorder),
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
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: cm.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _t(
                                                      '강의 자료',
                                                      'Course materials',
                                                    ),
                                                    style: TextStyle(
                                                      color: cm.textTertiary,
                                                    ),
                                                  ),
                                                  if (course
                                                      .tags
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 6,
                                                      children: course.tags.take(6).map((
                                                        tag,
                                                      ) {
                                                        return Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 3,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: cm.inputBg,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  cm.cardBorder,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            '#$tag',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: cm
                                                                  .textSecondary,
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                  if (course.memo
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      _trimPreview(
                                                        course.memo.trim(),
                                                        max: 100,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: cm.textTertiary,
                                                        height: 1.3,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<_CourseMenu>(
                                              color: cm.cardBg,
                                              surfaceTintColor:
                                                  Colors.transparent,
                                              shadowColor: cm.navBarShadow,
                                              elevation: 8,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                side: BorderSide(
                                                  color: cm.cardBorder,
                                                ),
                                              ),
                                              menuPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                              icon: Icon(
                                                Icons.more_horiz,
                                                color: cm.textHint,
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
                                              itemBuilder: (_) => [
                                                PopupMenuItem(
                                                  value: _CourseMenu.edit,
                                                  child: Text(
                                                    _t('수정', 'Edit'),
                                                    style: TextStyle(
                                                      color: cm.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: _CourseMenu.delete,
                                                  child: Text(
                                                    _t('삭제', 'Delete'),
                                                    style: TextStyle(
                                                      color: cm.deleteBg,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
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
                                                color: cm.pdfBadgeBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _t(
                                                  'PDF $pdfCount',
                                                  'PDF $pdfCount',
                                                ),
                                                style: TextStyle(
                                                  color: cm.pdfBadgeText,
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
                                                color: cm.memoBadgeBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _t(
                                                  '페이지 메모 $memoCount',
                                                  'Page notes $memoCount',
                                                ),
                                                style: TextStyle(
                                                  color: cm.memoBadgeText,
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
