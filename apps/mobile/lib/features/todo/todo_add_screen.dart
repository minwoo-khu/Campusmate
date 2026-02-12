import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import 'todo_model.dart';
import 'todo_repo.dart';

class TodoAddScreen extends StatefulWidget {
  final DateTime? initialDueAt;

  const TodoAddScreen({super.key, this.initialDueAt});

  @override
  State<TodoAddScreen> createState() => _TodoAddScreenState();
}

class _TodoAddScreenState extends State<TodoAddScreen> {
  final _titleController = TextEditingController();

  DateTime? _dueAt;
  DateTime? _remindAt;
  TodoRepeat _repeat = TodoRepeat.none;
  TodoPriority _priority = TodoPriority.none;

  @override
  void initState() {
    super.initState();
    if (widget.initialDueAt != null) {
      final d = widget.initialDueAt!;
      _dueAt = DateTime(d.year, d.month, d.day, 23, 59);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _fmtDateTime(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _repeatLabel(TodoRepeat rule) {
    switch (rule) {
      case TodoRepeat.none:
        return context.tr('없음', 'None');
      case TodoRepeat.daily:
        return context.tr('매일', 'Daily');
      case TodoRepeat.weekly:
        return context.tr('매주', 'Weekly');
    }
  }

  String _priorityLabel(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.none:
        return context.tr('없음', 'None');
      case TodoPriority.low:
        return context.tr('낮음', 'Low');
      case TodoPriority.medium:
        return context.tr('보통', 'Medium');
      case TodoPriority.high:
        return context.tr('높음', 'High');
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final base = _dueAt ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: DateTime(base.year, base.month, base.day),
    );
    if (pickedDate == null) return;

    setState(() {
      _dueAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        23,
        59,
      );
      if (_remindAt != null && _remindAt!.isAfter(_dueAt!)) {
        _remindAt = _dueAt;
      }
    });
  }

  void _clearDueDate() {
    setState(() => _dueAt = null);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final base = _remindAt ?? _dueAt ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
      initialDate: DateTime(base.year, base.month, base.day),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null) return;

    final candidate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (_dueAt != null && candidate.isAfter(_dueAt!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                '리마인더는 마감 이전이어야 합니다.',
                'Reminder must be before due time.',
              ),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _remindAt = candidate);
  }

  void _clearReminder() {
    setState(() => _remindAt = null);
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final item = TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      dueAt: _dueAt,
      remindAt: _remindAt,
      repeatRule: _repeat,
      completed: false,
      priorityLevel: _priority,
    );

    await todoRepo.add(item);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final dueText = _dueAt == null
        ? context.tr('없음', 'None')
        : _fmtDateTime(_dueAt!);
    final remindText = _remindAt == null
        ? context.tr('없음', 'None')
        : _fmtDateTime(_remindAt!);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('할 일 추가', 'Add Todo'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr('제목', 'Title'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cm.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: context.tr('할 일을 입력하세요', 'Enter todo title'),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('마감 (선택)', 'Due (optional)'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cm.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('${context.tr('마감', 'Due')}: $dueText')),
              TextButton(
                onPressed: _pickDueDate,
                child: Text(context.tr('날짜 선택', 'Pick date')),
              ),
              TextButton(
                onPressed: _dueAt == null ? null : _clearDueDate,
                child: Text(context.tr('지우기', 'Clear')),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            context.tr('리마인더 (선택)', 'Reminder (optional)'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cm.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('${context.tr('리마인더', 'Reminder')}: $remindText'),
              ),
              TextButton(
                onPressed: _pickReminder,
                child: Text(context.tr('시간 선택', 'Pick time')),
              ),
              TextButton(
                onPressed: _remindAt == null ? null : _clearReminder,
                child: Text(context.tr('지우기', 'Clear')),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            context.tr('반복', 'Repeat'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cm.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TodoRepeat>(
            initialValue: _repeat,
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
              setState(() => _repeat = value);
            },
          ),
          const Divider(height: 24),
          Text(
            context.tr('우선순위', 'Priority'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cm.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: TodoPriority.values.map((p) {
              final selected = _priority == p;
              return ChoiceChip(
                label: Text(_priorityLabel(p)),
                selected: selected,
                onSelected: (_) => setState(() => _priority = p),
                avatar: p == TodoPriority.none
                    ? null
                    : Icon(Icons.flag, size: 16, color: _priorityColor(p, cm)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(context.tr('저장', 'Save')),
          ),
        ],
      ),
    );
  }
}
