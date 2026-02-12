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

  const TodoScreen({
    super.key,
    this.highlightTodoIdListenable,
  });

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final ScrollController _scroll = ScrollController();

  String? _highlightId;
  DateTime? _highlightUntil;
  _TodoViewFilter _filter = _TodoViewFilter.all;

  @override
  void initState() {
    super.initState();
    widget.highlightTodoIdListenable?.addListener(_onHighlightChanged);
    _highlightId = widget.highlightTodoIdListenable?.value;
  }

  @override
  void dispose() {
    widget.highlightTodoIdListenable?.removeListener(_onHighlightChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onHighlightChanged() {
    final id = widget.highlightTodoIdListenable?.value;
    if (id == null) return;

    setState(() {
      _highlightId = id;
      _highlightUntil = DateTime.now().add(const Duration(milliseconds: 2500));
      _filter = _TodoViewFilter.all;
    });

    // 실제 스크롤은 build에서 items를 만든 뒤에 처리해야 하므로
    // 여기서는 setState만 하고, build에서 postFrame으로 스크롤.
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
    final d = _ymd(dt);

    if (_sameYmd(d, today)) return '오늘 ${_fmtHm(dt)}';
    if (_sameYmd(d, tomorrow)) return '내일 ${_fmtHm(dt)}';
    return '${_fmtYmd(dt)} ${_fmtHm(dt)}';
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

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
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

  Future<void> _setReminder(BuildContext context, TodoItem t) async {
    final base = t.remindAt ?? t.dueAt ?? DateTime.now();
    final picked = await _pickDateTime(context, base);
    if (picked == null) return;

    final due = t.dueAt;
    if (due != null && picked.isAfter(due)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리마인더는 마감시간 이후로 설정할 수 없어.')),
        );
      }
      return;
    }

    t.remindAt = picked;
    await todoRepo.update(t);
  }

  Future<void> _clearReminder(TodoItem t) async {
    t.remindAt = null;
    await todoRepo.update(t);
  }

  Future<void> _confirmDelete(BuildContext context, TodoItem t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제할까?'),
        content: Text('"${t.title}"'),
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

    if (ok == true) {
      await todoRepo.remove(t);
    }
  }

  Future<void> _openEdit(BuildContext context, TodoItem t) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TodoEditScreen(item: t)),
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
          final items = _applyFilter(allItems);

          // --- 하이라이트 스크롤 처리 (items가 준비된 뒤) ---
          final id = _highlightId;
          if (id != null) {
            final idx = items.indexWhere((t) => t.id == id);
            if (idx >= 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scroll.hasClients) {
                  // 대략적인 항목 높이로 스크롤 (trailing 폭 줄였으니 안정적)
                  const estTileH = 76.0;
                  final target =
                      (idx * estTileH).clamp(0.0, _scroll.position.maxScrollExtent);
                  _scroll.animateTo(
                    target,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              });
            }

            // 한 번 처리 후 값 지워서 반복 방지
            AppLink.clearTodo();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('전체'),
                      selected: _filter == _TodoViewFilter.all,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _filter == _TodoViewFilter.all ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) => setState(() => _filter = _TodoViewFilter.all),
                    ),
                    ChoiceChip(
                      label: const Text('진행'),
                      selected: _filter == _TodoViewFilter.active,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _filter == _TodoViewFilter.active ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) => setState(() => _filter = _TodoViewFilter.active),
                    ),
                    ChoiceChip(
                      label: const Text('완료'),
                      selected: _filter == _TodoViewFilter.done,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _filter == _TodoViewFilter.done ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) => setState(() => _filter = _TodoViewFilter.completed),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('조건에 맞는 Todo가 없어.'))
                    : ListView.builder(
                        controller: _scroll,
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final t = items[i];
                          final due = t.dueAt;
                          final remind = t.remindAt;

                          final dueStr = due == null ? null : _fmtYmd(due.toLocal());
                          final remindStr = (remind == null || t.completed)
                              ? null
                              : _fmtReminderLabel(remind.toLocal());

                          final isHighlight = (_highlightId != null &&
                              t.id == _highlightId &&
                              _highlightUntil != null &&
                              DateTime.now().isBefore(_highlightUntil!));

                          return Dismissible(
                            key: ValueKey('${t.key}_${t.id}'),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) async {
                              await todoRepo.remove(t);
                            },
                            child: ListTile(
                              tileColor: isHighlight
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              onTap: () => _openEdit(context, t),
                              leading: Checkbox(
                                value: t.completed,
                                onChanged: (_) async {
                                  await todoRepo.toggle(t);
                                  setState(() {}); // highlight 유지/표시 갱신용
                                },
                              ),
                              title: Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  decoration:
                                      t.completed ? TextDecoration.lineThrough : null,
                                ),
                              ),

                              subtitle: (dueStr == null && remindStr == null)
                                  ? null
                                  : Text(
                                      [
                                        if (dueStr != null) 'Due: $dueStr',
                                        if (remindStr != null) '🔔 $remindStr',
                                      ].join('  ·  '),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: PopupMenuButton<_TodoMenu>(
                                tooltip: '메뉴',
                                onSelected: (m) async {
                                  if (m == _TodoMenu.edit) {
                                    await _openEdit(context, t);
                                  } else if (m == _TodoMenu.delete) {
                                    await _confirmDelete(context, t);
                                  } else if (m == _TodoMenu.setReminder) {
                                    await _setReminder(context, t);
                                  } else if (m == _TodoMenu.clearReminder) {
                                    await _clearReminder(t);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: _TodoMenu.edit,
                                    child: Text('수정'),
                                  ),
                                  const PopupMenuItem(
                                    value: _TodoMenu.delete,
                                    child: Text('삭제'),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: _TodoMenu.setReminder,
                                    child: Text('리마인더 설정'),
                                  ),
                                  PopupMenuItem(
                                    value: _TodoMenu.clearReminder,
                                    enabled: t.remindAt != null,
                                    child: const Text('리마인더 해제'),
                                  ),
                                ],
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
