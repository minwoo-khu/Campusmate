import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/app_link.dart';
import 'todo_add_screen.dart';
import 'todo_edit_screen.dart';
import 'todo_model.dart';
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

  String _fmtReminderLabel(DateTime dt) {
    final now = DateTime.now();
    final today = _ymd(now);
    final tomorrow = today.add(const Duration(days: 1));
    final day = _ymd(dt);

    if (_sameYmd(day, today)) return 'Today ${_fmtHm(dt)}';
    if (_sameYmd(day, tomorrow)) return 'Tomorrow ${_fmtHm(dt)}';
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

  List<_TodoSection> _buildSections(List<TodoItem> items) {
    if (items.isEmpty) return const [];

    if (_filter == _TodoViewFilter.completed) {
      return [_TodoSection(title: 'Completed', items: items)];
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

    final sections = <_TodoSection>[];
    if (overdue.isNotEmpty) {
      sections.add(_TodoSection(title: 'Overdue', items: overdue));
    }
    if (todayItems.isNotEmpty) {
      sections.add(_TodoSection(title: 'Today', items: todayItems));
    }
    if (upcoming.isNotEmpty) {
      sections.add(_TodoSection(title: 'Upcoming', items: upcoming));
    }
    if (noDueDate.isNotEmpty) {
      sections.add(_TodoSection(title: 'No due date', items: noDueDate));
    }

    if (_filter == _TodoViewFilter.all && completed.isNotEmpty) {
      sections.add(_TodoSection(title: 'Completed', items: completed));
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

  Future<void> _quickAdd() async {
    final title = _quickTitleController.text.trim();
    if (title.isEmpty) return;

    final due = _quickDueAt;
    final remind = _quickRemindAt;
    if (due != null && remind != null && remind.isAfter(due)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder must be before due time.')),
        );
      }
      return;
    }

    final item = TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      dueAt: due,
      remindAt: remind,
      repeatRule: _quickRepeat,
      completed: false,
    );

    await todoRepo.add(item);

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _quickTitleController.clear();
      _quickDueAt = _defaultQuickDue();
      _quickRemindAt = null;
      _quickRepeat = TodoRepeat.none;
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
          const SnackBar(content: Text('Reminder must be before due time.')),
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
          const SnackBar(content: Text('Reminder must be before due time.')),
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

  Future<void> _confirmDelete(BuildContext context, TodoItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete todo?'),
        content: Text('"${item.title}"'),
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

    if (ok == true) {
      await todoRepo.remove(item);
    }
  }

  Future<void> _openEdit(BuildContext context, TodoItem item) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => TodoEditScreen(item: item)));
  }

  Widget _buildQuickCapture() {
    final dueLabel = _quickDueAt == null ? 'None' : _fmtYmd(_quickDueAt!);
    final reminderLabel = _quickRemindAt == null
        ? 'None'
        : _fmtReminderLabel(_quickRemindAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickTitleController,
                    decoration: const InputDecoration(
                      hintText: 'Quick capture...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _quickAdd(),
                  ),
                ),
                IconButton(
                  tooltip: _quickExpanded ? 'Hide options' : 'Show options',
                  onPressed: () {
                    setState(() => _quickExpanded = !_quickExpanded);
                  },
                  icon: Icon(_quickExpanded ? Icons.expand_less : Icons.tune),
                ),
                FilledButton(onPressed: _quickAdd, child: const Text('Add')),
              ],
            ),
            if (_quickExpanded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Due: $dueLabel')),
                  TextButton(
                    onPressed: _pickQuickDueDate,
                    child: const Text('Pick'),
                  ),
                  TextButton(
                    onPressed: _quickDueAt == null
                        ? null
                        : () {
                            setState(() {
                              _quickDueAt = null;
                            });
                          },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text('Reminder: $reminderLabel')),
                  TextButton(
                    onPressed: _pickQuickReminder,
                    child: const Text('Pick'),
                  ),
                  TextButton(
                    onPressed: _quickRemindAt == null
                        ? null
                        : () {
                            setState(() {
                              _quickRemindAt = null;
                            });
                          },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              DropdownButtonFormField<TodoRepeat>(
                initialValue: _quickRepeat,
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: TodoRepeat.values
                    .map(
                      (rule) => DropdownMenuItem<TodoRepeat>(
                        value: rule,
                        child: Text(rule.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _quickRepeat = value);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(_TodoListRow row) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Text(
            row.title!,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Text('${row.count}', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildTodoTile(TodoItem item) {
    final due = item.dueAt;
    final remind = item.remindAt;

    final dueStr = due == null ? null : _fmtYmd(due.toLocal());
    final remindStr = (remind == null || item.completed)
        ? null
        : _fmtReminderLabel(remind.toLocal());
    final repeatStr = item.repeatRule == TodoRepeat.none
        ? null
        : 'Repeat: ${item.repeatRule.label}';

    final subtitleParts = <String>[
      if (dueStr != null) 'Due: $dueStr',
      if (remindStr != null) 'Remind: $remindStr',
      if (repeatStr != null) repeatStr,
    ];

    final isHighlight =
        (_highlightId != null &&
        item.id == _highlightId &&
        _highlightUntil != null &&
        DateTime.now().isBefore(_highlightUntil!));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('${item.key}_${item.id}'),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) async {
          await todoRepo.remove(item);
        },
        child: Card(
          color: isHighlight
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            onTap: () => _openEdit(context, item),
            leading: Checkbox(
              value: item.completed,
              onChanged: (_) async {
                await todoRepo.toggle(item);
                setState(() {});
              },
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: item.completed ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: subtitleParts.isEmpty
                ? null
                : Text(
                    subtitleParts.join('  |  '),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: PopupMenuButton<_TodoMenu>(
              tooltip: 'Menu',
              onSelected: (menu) async {
                if (menu == _TodoMenu.edit) {
                  await _openEdit(context, item);
                } else if (menu == _TodoMenu.delete) {
                  await _confirmDelete(context, item);
                } else if (menu == _TodoMenu.setReminder) {
                  await _setReminder(context, item);
                } else if (menu == _TodoMenu.clearReminder) {
                  await _clearReminder(item);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: _TodoMenu.edit, child: Text('Edit')),
                const PopupMenuItem(
                  value: _TodoMenu.delete,
                  child: Text('Delete'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: _TodoMenu.setReminder,
                  child: Text('Set reminder'),
                ),
                PopupMenuItem(
                  value: _TodoMenu.clearReminder,
                  enabled: item.remindAt != null,
                  child: const Text('Clear reminder'),
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
    final box = Hive.box<TodoItem>('todos');

    return Scaffold(
      body: ValueListenableBuilder(
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
                  const estimatedRowHeight = 82.0;
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: _buildQuickCapture(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(
                          'All $totalCount',
                          style: TextStyle(
                            color: _filter == _TodoViewFilter.all
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        selected: _filter == _TodoViewFilter.all,
                        onSelected: (_) =>
                            setState(() => _filter = _TodoViewFilter.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          'Active $activeCount',
                          style: TextStyle(
                            color: _filter == _TodoViewFilter.active
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        selected: _filter == _TodoViewFilter.active,
                        onSelected: (_) =>
                            setState(() => _filter = _TodoViewFilter.active),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          'Completed $completedCount',
                          style: TextStyle(
                            color: _filter == _TodoViewFilter.completed
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        selected: _filter == _TodoViewFilter.completed,
                        onSelected: (_) =>
                            setState(() => _filter = _TodoViewFilter.completed),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No todos in this view.'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const TodoAddScreen()),
          );
        },
        child: const Icon(Icons.add),
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
