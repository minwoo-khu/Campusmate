import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/courses/course.dart';
import '../features/courses/course_material.dart';
import '../features/todo/todo_model.dart';
import 'campusmate_logo.dart';
import 'l10n.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onNavigateToTab;

  const HomeScreen({
    super.key,
    required this.onOpenSettings,
    required this.onNavigateToTab,
  });

  String _t(BuildContext context, String ko, String en) => context.tr(ko, en);

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _fmtHm(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final todoBox = Hive.box<TodoItem>('todos');
    final courseBox = Hive.box<Course>('courses');
    final materialBox = Hive.box<CourseMaterial>('course_materials');

    return Scaffold(
      backgroundColor: cm.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              todoBox.listenable(),
              courseBox.listenable(),
              materialBox.listenable(),
            ]),
            builder: (context, _) {
              final todos = todoBox.values.toList();
              final courses = courseBox.values.toList();
              final materials = materialBox.values.toList();

              final now = DateTime.now();
              final today = _ymd(now);

              final activeTodos = todos.where((t) => !t.completed).toList();
              final completedTodos = todos.where((t) => t.completed).length;
              final overdue = activeTodos.where((t) {
                final due = t.dueAt;
                if (due == null) return false;
                return _ymd(due).isBefore(today);
              }).length;
              final dueToday = activeTodos.where((t) {
                final due = t.dueAt;
                if (due == null) return false;
                return _ymd(due) == today;
              }).length;

              final nextTodo = () {
                final withDue =
                    activeTodos.where((t) => t.dueAt != null).toList()
                      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
                return withDue.isEmpty ? null : withDue.first;
              }();

              final totalPdfCount = materials.length;
              final taggedCourseCount = courses
                  .where((c) => c.tags.isNotEmpty || c.memo.trim().isNotEmpty)
                  .length;

              final recommendation = () {
                if (courses.isEmpty) {
                  return _t(
                    context,
                    '강의를 추가하면 과목별 자료/메모를 정리할 수 있어요.',
                    'Add a course to organize materials and notes by subject.',
                  );
                }
                if (activeTodos.isEmpty) {
                  return _t(
                    context,
                    '오늘 할 일을 추가해서 하루 계획을 시작해 보세요.',
                    'Add a todo to start planning your day.',
                  );
                }
                if (totalPdfCount == 0) {
                  return _t(
                    context,
                    '강의 탭에서 PDF를 추가해 수업 자료를 모아보세요.',
                    'Upload PDFs in Courses to keep your class materials together.',
                  );
                }
                return _t(
                  context,
                  '캘린더 탭에서 마감 일정과 학교 일정을 함께 확인해 보세요.',
                  'Check due dates and school events together in Calendar.',
                );
              }();

              return ListView(
                children: [
                  Row(
                    children: [
                      const CampusMateLogo(size: 40),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CampusMate',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: cm.textPrimary,
                            ),
                          ),
                          Text(
                            _fmtDate(now),
                            style: TextStyle(color: cm.textTertiary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _t(context, '설정', 'Settings'),
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor: cm.iconButtonBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, '오늘 요약', 'Today overview'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                label: _t(context, '진행 중', 'Active'),
                                value: '${activeTodos.length}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: _t(context, '오늘 마감', 'Due today'),
                                value: '$dueToday',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: _t(context, '기한 지남', 'Overdue'),
                                value: '$overdue',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          nextTodo == null
                              ? _t(
                                  context,
                                  '다가오는 마감 할 일이 없습니다.',
                                  'No upcoming due todo.',
                                )
                              : _t(
                                  context,
                                  '다음 마감: ${nextTodo.title} (${_fmtDate(nextTodo.dueAt!)} ${_fmtHm(nextTodo.dueAt!)})',
                                  'Next due: ${nextTodo.title} (${_fmtDate(nextTodo.dueAt!)} ${_fmtHm(nextTodo.dueAt!)})',
                                ),
                          style: TextStyle(
                            color: cm.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, '빠른 이동', 'Quick actions'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.check_circle_outline,
                                label: _t(context, '할 일', 'Todo'),
                                onTap: () => onNavigateToTab(1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.calendar_month_outlined,
                                label: _t(context, '캘린더', 'Calendar'),
                                onTap: () => onNavigateToTab(2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.image_outlined,
                                label: _t(context, '시간표', 'Timetable'),
                                onTap: () => onNavigateToTab(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.menu_book_outlined,
                                label: _t(context, '강의', 'Courses'),
                                onTap: () => onNavigateToTab(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, '홈에 넣을 추천 정보', 'Suggested for home'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: cm.navActive,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                recommendation,
                                style: TextStyle(
                                  color: cm.textTertiary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, '학습 현황', 'Study status'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                label: _t(
                                  context,
                                  '완료한 할 일',
                                  'Completed todos',
                                ),
                                value: '$completedTodos',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: _t(context, '등록 PDF', 'PDF files'),
                                value: '$totalPdfCount',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: _t(
                                  context,
                                  '메모/태그 강의',
                                  'Tagged courses',
                                ),
                                value: '$taggedCourseCount',
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cm.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cm.cardBorder),
      ),
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cm.inputBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cm.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: cm.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: cm.textSecondary,
        side: BorderSide(color: cm.cardBorder),
        backgroundColor: cm.inputBg,
      ),
    );
  }
}
