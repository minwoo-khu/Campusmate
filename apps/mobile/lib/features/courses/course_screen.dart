import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/change_history_service.dart';
import '../../app/change_history_sheet.dart';
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

  Future<void> _deleteCourseWithUndo(
    BuildContext context,
    Course course,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete course?'),
        content: Text(course.name),
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

    if (ok != true) return;

    final backup = Course(id: course.id, name: course.name);
    await course.delete();
    await ChangeHistoryService.log('Course deleted', detail: backup.name);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${backup.name}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await Hive.box<Course>('courses').add(backup);
            await ChangeHistoryService.log(
              'Course restored',
              detail: backup.name,
            );
          },
        ),
      ),
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
                        'Courses',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: cm.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Recent changes',
                        onPressed: () => showChangeHistorySheet(context),
                        icon: const Icon(Icons.history),
                        style: IconButton.styleFrom(
                          backgroundColor: cm.iconButtonBg,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                      hintText: 'Search course, PDF name, note text, tag...',
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
                      'Course dashboard',
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
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                                  const SizedBox(height: 8),
                                  Text(
                                    'Linked todos (7d): $linkedTodos',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cm.navActive,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Latest PDF: ${latestMaterial ?? 'No PDF yet'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cm.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Recent memo: ${latestMemo == null ? 'No memo yet' : _trimPreview(latestMemo)}',
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
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'No matching course found.',
                                  style: TextStyle(color: cm.textTertiary),
                                ),
                              ),
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
                                        'PDF learning mode',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: cm.tipBannerTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Open materials and attach page-level notes/tags. Search now supports these notes.',
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
                                                    'Course materials',
                                                    style: TextStyle(
                                                      color: cm.textTertiary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<_CourseMenu>(
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
                                                  await _deleteCourseWithUndo(
                                                    context,
                                                    course,
                                                  );
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: _CourseMenu.edit,
                                                  child: Text('Edit'),
                                                ),
                                                PopupMenuItem(
                                                  value: _CourseMenu.delete,
                                                  child: Text('Delete'),
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
                                                'PDF $pdfCount',
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
                                                'Page notes $memoCount',
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
