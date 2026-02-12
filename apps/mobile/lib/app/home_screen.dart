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

              final recos = <String>[];
              if (overdue > 0) {
                recos.add(
                  _t(
                    context,
                    '기한 지난 할 일 $overdue개를 먼저 정리해보세요.',
                    'Handle $overdue overdue todos first.',
                  ),
                );
              }
              if (dueToday > 0) {
                recos.add(
                  _t(
                    context,
                    '오늘 마감 $dueToday개가 있습니다.',
                    '$dueToday todos are due today.',
                  ),
                );
              }
              if (courses.isEmpty) {
                recos.add(
                  _t(
                    context,
                    '강의를 추가하면 과목별 자료/메모를 모아볼 수 있어요.',
                    'Add your first course to organize materials and notes.',
                  ),
                );
              } else if (materials.isEmpty) {
                recos.add(
                  _t(
                    context,
                    '강의 자료 PDF를 올려서 페이지 메모를 시작해보세요.',
                    'Upload course PDFs and start page-level notes.',
                  ),
                );
              }

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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cm.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cm.cardBorder),
                    ),
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
                            _StatChip(
                              label: _t(context, '진행 중', 'Active'),
                              value: '${activeTodos.length}',
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              label: _t(context, '오늘 마감', 'Due today'),
                              value: '$dueToday',
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              label: _t(context, '기한 지남', 'Overdue'),
                              value: '$overdue',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          nextTodo == null
                              ? _t(
                                  context,
                                  '다음 마감 할 일이 없습니다.',
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cm.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cm.cardBorder),
                    ),
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cm.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cm.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, '홈에 넣을 추천 정보', 'Suggested home content'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cm.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (recos.isEmpty)
                          Text(
                            _t(
                              context,
                              '오늘은 추천 항목이 없습니다. 계획대로 진행해도 좋아요.',
                              'No recommendations for now. You are on track.',
                            ),
                            style: TextStyle(color: cm.textTertiary),
                          )
                        else
                          ...recos.map(
                            (text) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(
                                      Icons.bolt,
                                      size: 14,
                                      color: cm.navActive,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: TextStyle(color: cm.textTertiary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cm.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
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
            Text(label, style: TextStyle(fontSize: 11, color: cm.textTertiary)),
          ],
        ),
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
