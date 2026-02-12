import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/app_link.dart';
import '../../app/change_history_service.dart';
import '../../app/change_history_sheet.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';
import 'todo_edit_screen.dart';
import 'todo_model.dart';
import 'todo_quick_capture_parser.dart';
import 'todo_repo.dart';

class TodoScreen extends StatefulWidget {
  final ValueListenable<String?>? highlightTodoIdListenable;

  const TodoScreen({super.key, this.highlightTodoIdListenable});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _quickTitleController = TextEditingController();

  String? _highlightId;
  DateTime? _highlightUntil;
  _TodoViewFilter _filter = _TodoViewFilter.all;

  bool _quickExpanded = false;
  DateTime? _quickDueAt;
  DateTime? _quickRemindAt;
  TodoRepeat _quickRepeat = TodoRepeat.none;
  TodoPriority _quickPriority = TodoPriority.none;

  @override
  void initState() {
    super.initState();
    widget.highlightTodoIdListenable?.addListener(_onHighlightChanged);
    _highlightId = widget.highlightTodoIdListenable?.value;
    _quickDueAt = _defaultQuickDue();
  }

  @override
  void dispose() {
    widget.highlightTodoIdListenable?.removeListener(_onHighlightChanged);
    _quickTitleController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  DateTime _defaultQuickDue() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59);
  }

  void _onHighlightChanged() {
    final id = widget.highlightTodoIdListenable?.value;
    if (id == null) return;

    setState(() {
      _highlightId = id;
      _highlightUntil = DateTime.now().add(const Duration(milliseconds: 2500));
      _filter = _TodoViewFilter.all;
    });
  }

  String _two(int x) => x.toString().padLeft(2, '0');

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameYmd(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtYmd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  String _fmtHm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  String _t(String ko, String en) => context.tr(ko, en);

  String _repeatLabel(TodoRepeat rule) {
    switch (rule) {
      case TodoRepeat.none:
        return _t('없음', 'None');
      case TodoRepeat.daily:
        return _t('매일', 'Daily');
      case TodoRepeat.weekly:
        return _t('매주', 'Weekly');
    }
  }

  String _priorityLabel(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.none:
        return _t('없음', 'None');
      case TodoPriority.low:
        return _t('낮음', 'Low');
      case TodoPriority.medium:
        return _t('보통', 'Medium');
      case TodoPriority.high:
        return _t('높음', 'High');
    }
  }

  String _fmtReminderLabel(DateTime dt) {
    final now = DateTime.now();
    final today = _ymd(now);
    final tomorrow = today.add(const Duration(days: 1));
    final day = _ymd(dt);

    if (_sameYmd(day, today))
      return _t('오늘 ${_fmtHm(dt)}', 'Today ${_fmtHm(dt)}');
    if (_sameYmd(day, tomorrow)) {
      return _t('내일 ${_fmtHm(dt)}', 'Tomorrow ${_fmtHm(dt)}');
    }
    return '${_fmtYmd(dt)} ${_fmtHm(dt)}';
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDate: DateTime(initial.year, initial.month, initial.day),
    );
    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  List<TodoItem> _applyFilter(List<TodoItem> items) {
    switch (_filter) {
      case _TodoViewFilter.active:
        return items.where((t) => !t.completed).toList();
      case _TodoViewFilter.completed:
        return items.where((t) => t.completed).toList();
      case _TodoViewFilter.all:
        return items;
    }
  }

  int _priorityOrder(TodoPriority p) {
    switch (p) {
      case TodoPriority.high:
        return 0;
      case TodoPriority.medium:
        return 1;
      case TodoPriority.low:
        return 2;
      case TodoPriority.none:
        return 3;
    }
  }

  List<_TodoSection> _buildSections(List<TodoItem> items) {
    if (items.isEmpty) return const [];

    if (_filter == _TodoViewFilter.completed) {
      return [
        _TodoSection(
          title: _t('완료됨', 'Completed'),
          items: List<TodoItem>.from(items),
        ),
      ];
    }

    final now = DateTime.now();
    final today = _ymd(now);

    final overdue = <TodoItem>[];
    final todayItems = <TodoItem>[];
    final upcoming = <TodoItem>[];
    final noDueDate = <TodoItem>[];
    final completed = <TodoItem>[];

    for (final t in items) {
      if (t.completed) {
        completed.add(t);
        continue;
      }

      final due = t.dueAt;
      if (due == null) {
        noDueDate.add(t);
        continue;
      }

      final dueDay = _ymd(due);
      if (dueDay.isBefore(today)) {
        overdue.add(t);
      } else if (_sameYmd(dueDay, today)) {
        todayItems.add(t);
      } else {
        upcoming.add(t);
      }
    }

    // Sort each group by priority then due
    void sortByPriority(List<TodoItem> list) {
      list.sort((a, b) {
        final pc = _priorityOrder(
          a.priorityLevel,
        ).compareTo(_priorityOrder(b.priorityLevel));
        if (pc != 0) return pc;
        final da = a.dueAt;
        final db = b.dueAt;
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return 0;
      });
    }

    sortByPriority(overdue);
    sortByPriority(todayItems);
    sortByPriority(upcoming);
    sortByPriority(noDueDate);

    final sections = <_TodoSection>[];
    if (overdue.isNotEmpty) {
      sections.add(_TodoSection(title: _t('기한 지남', 'Overdue'), items: overdue));
    }
    if (todayItems.isNotEmpty) {
      sections.add(
        _TodoSection(
          title: _t('오늘 / 진행 중', 'Today / Active'),
          items: todayItems,
        ),
      );
    }
    if (upcoming.isNotEmpty) {
      sections.add(_TodoSection(title: _t('예정됨', 'Upcoming'), items: upcoming));
    }
    if (noDueDate.isNotEmpty) {
      sections.add(
        _TodoSection(title: _t('마감일 없음', 'No due date'), items: noDueDate),
      );
    }

    if (_filter == _TodoViewFilter.all && completed.isNotEmpty) {
      sections.add(
        _TodoSection(title: _t('완료됨', 'Completed'), items: completed),
      );
    }

    return sections;
  }

  List<_TodoListRow> _rowsFromSections(List<_TodoSection> sections) {
    final rows = <_TodoListRow>[];
    for (final section in sections) {
      rows.add(_TodoListRow.header(section.title, section.items.length));
      for (final item in section.items) {
        rows.add(_TodoListRow.item(item));
      }
    }
    return rows;
  }

  TodoItem _cloneTodo(TodoItem source) {
    return TodoItem(
      id: source.id,
      title: source.title,
      dueAt: source.dueAt,
      remindAt: source.remindAt,
      repeatRule: source.repeatRule,
      completed: source.completed,
      priorityLevel: source.priorityLevel,
    );
  }

  Future<void> _deleteTodoWithUndo(TodoItem item) async {
    final backup = _cloneTodo(item);
    await todoRepo.remove(item, logAction: false);
    await ChangeHistoryService.log('Todo deleted', detail: backup.title);

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('"${backup.title}" 삭제됨', 'Deleted "${backup.title}"')),
        action: SnackBarAction(
          label: _t('실행 취소', 'Undo'),
          onPressed: () async {
            await todoRepo.add(backup, logAction: false);
            await ChangeHistoryService.log(
              'Todo restored',
              detail: backup.title,
            );
          },
        ),
      ),
    );
  }

  Future<void> _quickAdd() async {
    final rawTitle = _quickTitleController.text.trim();
    if (rawTitle.isEmpty) return;

    var title = rawTitle;
    var due = _quickDueAt;
    var remind = _quickRemindAt;

    if (!_quickExpanded) {
      final parsed = QuickCaptureParser.parse(rawTitle);
      if (parsed.parsed) {
        title = parsed.title;
        if (parsed.dueAt != null) {
          due = parsed.dueAt;
          remind = parsed.remindAt;
        }
      }
    }

    if (title.trim().isEmpty) return;

    if (due != null && remind != null && remind.isAfter(due)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '리마인더는 마감 이후로 설정할 수 없습니다.',
                'Reminder cannot be later than due time.',
              ),
            ),
          ),
        );
      }
      return;
    }

    final item = TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      dueAt: due,
      remindAt: remind,
      repeatRule: _quickRepeat,
      completed: false,
      priorityLevel: _quickPriority,
    );

    await todoRepo.add(item);

    if (!mounted) return;

    setState(() {
      _quickTitleController.clear();
      _quickDueAt = _defaultQuickDue();
      _quickRemindAt = null;
      _quickRepeat = TodoRepeat.none;
      _quickPriority = TodoPriority.none;
      _quickExpanded = false;
    });
  }

  Future<void> _pickQuickDueDate() async {
    final now = DateTime.now();
    final base = _quickDueAt ?? now;

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: DateTime(base.year, base.month, base.day),
    );
    if (picked == null) return;

    setState(() {
      _quickDueAt = DateTime(picked.year, picked.month, picked.day, 23, 59);
      if (_quickRemindAt != null && _quickRemindAt!.isAfter(_quickDueAt!)) {
        _quickRemindAt = _quickDueAt;
      }
    });
  }

  Future<void> _pickQuickReminder() async {
    final base = _quickRemindAt ?? _quickDueAt ?? DateTime.now();
    final picked = await _pickDateTime(context, base);
    if (picked == null) return;

    if (_quickDueAt != null && picked.isAfter(_quickDueAt!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '리마인더는 마감 이후로 설정할 수 없습니다.',
                'Reminder cannot be later than due time.',
              ),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _quickRemindAt = picked);
  }

  Future<void> _setReminder(BuildContext context, TodoItem item) async {
    final base = item.remindAt ?? item.dueAt ?? DateTime.now();
    final picked = await _pickDateTime(context, base);
    if (picked == null) return;

    final due = item.dueAt;
    if (due != null && picked.isAfter(due)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '리마인더는 마감 이후로 설정할 수 없습니다.',
                'Reminder cannot be later than due time.',
              ),
            ),
          ),
        );
      }
      return;
    }

    item.remindAt = picked;
    await todoRepo.update(item);
  }

  Future<void> _clearReminder(TodoItem item) async {
    item.remindAt = null;
    await todoRepo.update(item);
  }

  Future<void> _openEdit(BuildContext context, TodoItem item) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => TodoEditScreen(item: item)));
  }

  Color _priorityColor(TodoPriority p, CampusMateColors cm) {
    switch (p) {
      case TodoPriority.high:
        return cm.priorityHigh;
      case TodoPriority.medium:
        return cm.priorityMedium;
      case TodoPriority.low:
        return cm.priorityLow;
      case TodoPriority.none:
        return cm.textHint;
    }
  }

  Widget _buildQuickCapture() {
    final cm = context.cmColors;
    final dueLabel = _quickDueAt == null
        ? _t('없음', 'None')
        : _fmtYmd(_quickDueAt!);
    final reminderLabel = _quickRemindAt == null
        ? _t('없음', 'None')
        : _fmtReminderLabel(_quickRemindAt!);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: cm.inputBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickTitleController,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: _t(
                      '빠른 입력 (예: 내일 9:30 운영체제 복습)',
                      'Quick capture (e.g. tomorrow 9:30 OS review)',
                    ),
                    hintStyle: TextStyle(color: cm.textHint),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _quickExpanded = !_quickExpanded);
                },
                icon: Icon(
                  _quickExpanded ? Icons.expand_less : Icons.tune,
                  color: cm.textTertiary,
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: FilledButton(
                  onPressed: _quickAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: cm.navActive,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add, size: 22),
                ),
              ),
            ],
          ),
          if (_quickExpanded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_t('마감', 'Due')}: $dueLabel',
                    style: TextStyle(color: cm.textTertiary, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _pickQuickDueDate,
                  child: Text(_t('선택', 'Pick')),
                ),
                TextButton(
                  onPressed: _quickDueAt == null
                      ? null
                      : () => setState(() => _quickDueAt = null),
                  child: Text(_t('지우기', 'Clear')),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_t('리마인더', 'Reminder')}: $reminderLabel',
                    style: TextStyle(color: cm.textTertiary, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _pickQuickReminder,
                  child: Text(_t('선택', 'Pick')),
                ),
                TextButton(
                  onPressed: _quickRemindAt == null
                      ? null
                      : () => setState(() => _quickRemindAt = null),
                  child: Text(_t('지우기', 'Clear')),
                ),
              ],
            ),
            DropdownButtonFormField<TodoRepeat>(
              initialValue: _quickRepeat,
              decoration: InputDecoration(
                isDense: true,
                labelText: _t('반복', 'Repeat'),
                border: const OutlineInputBorder(),
              ),
              items: TodoRepeat.values
                  .map(
                    (rule) => DropdownMenuItem<TodoRepeat>(
                      value: rule,
                      child: Text(_repeatLabel(rule)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _quickRepeat = value);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${_t('우선순위', 'Priority')}: ',
                  style: TextStyle(color: cm.textTertiary, fontSize: 12),
                ),
                const SizedBox(width: 8),
                ...TodoPriority.values.map((p) {
                  final selected = _quickPriority == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_priorityLabel(p)),
                      selected: selected,
                      onSelected: (_) => setState(() => _quickPriority = p),
                      avatar: p == TodoPriority.none
                          ? null
                          : Icon(
                              Icons.flag,
                              size: 14,
                              color: _priorityColor(p, cm),
                            ),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow(int totalCount, int activeCount, int completedCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('${_t('전체', 'All')} $totalCount'),
            selected: _filter == _TodoViewFilter.all,
            onSelected: (_) => setState(() => _filter = _TodoViewFilter.all),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('${_t('진행 중', 'Active')} $activeCount'),
            selected: _filter == _TodoViewFilter.active,
            onSelected: (_) => setState(() => _filter = _TodoViewFilter.active),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('${_t('완료', 'Completed')} $completedCount'),
            selected: _filter == _TodoViewFilter.completed,
            onSelected: (_) =>
                setState(() => _filter = _TodoViewFilter.completed),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(_TodoListRow row) {
    final cm = context.cmColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        children: [
          Text(
            row.title!,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: cm.sectionHeader,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${row.count}',
            style: TextStyle(color: cm.textHint, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaLine(TodoItem item) {
    final cm = context.cmColors;
    final due = item.dueAt;
    final reminder = item.remindAt;
    final priority = item.priorityLevel;

    final dueText = due == null
        ? null
        : _sameYmd(_ymd(due), _ymd(DateTime.now()))
        ? _t('오늘 마감', 'Due today')
        : _t('${_fmtYmd(due)} 마감', 'Due ${_fmtYmd(due)}');

    final parts = <Widget>[];

    // Priority indicator
    if (priority != TodoPriority.none) {
      final pColor = _priorityColor(priority, cm);
      parts.add(Icon(Icons.flag, size: 12, color: pColor));
      parts.add(const SizedBox(width: 3));
      parts.add(
        Text(
          _priorityLabel(priority),
          style: TextStyle(
            fontSize: 12,
            color: pColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (dueText != null) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 8));
      parts.add(Icon(Icons.schedule, size: 12, color: cm.textHint));
      parts.add(const SizedBox(width: 3));
      parts.add(
        Text(dueText, style: TextStyle(fontSize: 12, color: cm.textHint)),
      );
    }

    if (reminder != null && !item.completed) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(width: 8));
      }
      parts.add(Icon(Icons.notifications_none, size: 12, color: cm.navActive));
      parts.add(const SizedBox(width: 3));
      parts.add(
        Text(
          _fmtReminderLabel(reminder),
          style: TextStyle(fontSize: 12, color: cm.navActive),
        ),
      );
    }

    if (item.repeatRule != TodoRepeat.none) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(width: 8));
      }
      parts.add(Icon(Icons.repeat, size: 12, color: cm.textHint));
      parts.add(const SizedBox(width: 3));
      parts.add(
        Text(
          _repeatLabel(item.repeatRule),
          style: TextStyle(fontSize: 12, color: cm.textHint),
        ),
      );
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }

  Widget _buildTodoTile(TodoItem item) {
    final cm = context.cmColors;
    final isHighlight =
        _highlightId != null &&
        item.id == _highlightId &&
        _highlightUntil != null &&
        DateTime.now().isBefore(_highlightUntil!);

    final completed = item.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('${item.key}_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: cm.deleteBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) async => _deleteTodoWithUndo(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: completed ? cm.tileCompletedBg : cm.tileBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHighlight ? cm.tileHighlightBorder : cm.tileBorder,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            onTap: () => _openEdit(context, item),
            leading: IconButton(
              onPressed: () async {
                await todoRepo.toggle(item);
                setState(() {});
              },
              icon: Icon(
                completed ? Icons.check_circle : Icons.circle_outlined,
                color: completed ? cm.checkActive : cm.checkInactive,
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: completed ? cm.textHint : cm.textPrimary,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildMetaLine(item),
            ),
            trailing: PopupMenuButton<_TodoMenu>(
              icon: Icon(Icons.more_horiz, color: cm.textHint),
              onSelected: (menu) async {
                if (menu == _TodoMenu.edit) {
                  await _openEdit(context, item);
                } else if (menu == _TodoMenu.delete) {
                  await _deleteTodoWithUndo(item);
                } else if (menu == _TodoMenu.setReminder) {
                  await _setReminder(context, item);
                } else if (menu == _TodoMenu.clearReminder) {
                  await _clearReminder(item);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _TodoMenu.edit,
                  child: Text(_t('수정', 'Edit')),
                ),
                PopupMenuItem(
                  value: _TodoMenu.delete,
                  child: Text(_t('삭제', 'Delete')),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _TodoMenu.setReminder,
                  child: Text(_t('리마인더 설정', 'Set reminder')),
                ),
                PopupMenuItem(
                  value: _TodoMenu.clearReminder,
                  enabled: item.remindAt != null,
                  child: Text(_t('리마인더 해제', 'Clear reminder')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final box = Hive.box<TodoItem>('todos');

    return Scaffold(
      backgroundColor: cm.scaffoldBg,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<TodoItem> b, _) {
            final allItems = todoRepo.list();
            final filteredItems = _applyFilter(allItems);
            final sections = _buildSections(filteredItems);
            final rows = _rowsFromSections(sections);

            final id = _highlightId;
            if (id != null) {
              final idx = rows.indexWhere((row) => row.todo?.id == id);
              if (idx >= 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    const estimatedRowHeight = 86.0;
                    final target = (idx * estimatedRowHeight).clamp(
                      0.0,
                      _scroll.position.maxScrollExtent,
                    );
                    _scroll.animateTo(
                      target,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                });
              }
              AppLink.clearTodo();
            }

            final totalCount = allItems.length;
            final activeCount = allItems.where((t) => !t.completed).length;
            final completedCount = allItems.where((t) => t.completed).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        _t('할 일', 'Todo'),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: cm.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _t('최근 변경', 'Recent changes'),
                        onPressed: () => showChangeHistorySheet(context),
                        icon: const Icon(Icons.history),
                        style: IconButton.styleFrom(
                          backgroundColor: cm.iconButtonBg,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _buildQuickCapture(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: _buildFilterRow(
                    totalCount,
                    activeCount,
                    completedCount,
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            _t(
                              '필터 조건에 맞는 할 일이 없습니다.',
                              'No todos for this filter.',
                            ),
                            style: TextStyle(color: cm.textTertiary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: rows.length,
                          itemBuilder: (_, i) {
                            final row = rows[i];
                            if (row.isHeader) {
                              return _buildSectionHeader(row);
                            }
                            return _buildTodoTile(row.todo!);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _TodoMenu { edit, delete, setReminder, clearReminder }

enum _TodoViewFilter { all, active, completed }

class _TodoSection {
  final String title;
  final List<TodoItem> items;

  const _TodoSection({required this.title, required this.items});
}

class _TodoListRow {
  final String? title;
  final int count;
  final TodoItem? todo;

  const _TodoListRow.header(this.title, this.count) : todo = null;

  const _TodoListRow.item(this.todo) : title = null, count = 0;

  bool get isHeader => title != null;
}
