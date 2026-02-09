import 'package:flutter/material.dart';

import 'todo_model.dart';
import 'todo_repo.dart';

class TodoEditScreen extends StatefulWidget {
  final TodoItem item;

  const TodoEditScreen({
    super.key,
    required this.item,
  });

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  late final TextEditingController _titleController;

  DateTime? _dueAt;
  DateTime? _remindAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _dueAt = widget.item.dueAt;
    _remindAt = widget.item.remindAt;
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
      _dueAt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 23, 59);
      if (_remindAt != null && _remindAt!.isAfter(_dueAt!)) {
        _remindAt = _dueAt;
      }
    });
  }

  void _clearDueDate() {
    setState(() {
      _dueAt = null;
    });
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
          const SnackBar(content: Text('리마인더는 마감시간 이후로 설정할 수 없어.')),
        );
      }
      return;
    }

    setState(() => _remindAt = candidate);
  }

  void _clearReminder() {
    setState(() => _remindAt = null);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    widget.item.title = title;
    widget.item.dueAt = _dueAt;
    widget.item.remindAt = _remindAt;

    await todoRepo.update(widget.item);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    await todoRepo.remove(widget.item);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _dueAt == null ? '없음' : _fmtDateTime(_dueAt!);
    final remindText = _remindAt == null ? '없음' : _fmtDateTime(_remindAt!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo 수정'),
        actions: [
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('할 일', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '예) 운영체제 과제 제출',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),

          const SizedBox(height: 16),
          const Text('마감(선택)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('마감: $dueText')),
              TextButton(onPressed: _pickDueDate, child: const Text('날짜 선택')),
              TextButton(onPressed: _dueAt == null ? null : _clearDueDate, child: const Text('지우기')),
            ],
          ),

          const Divider(height: 24),

          const Text('리마인더(선택)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('알림: $remindText')),
              TextButton(onPressed: _pickReminder, child: const Text('시간 선택')),
              TextButton(onPressed: _remindAt == null ? null : _clearReminder, child: const Text('지우기')),
            ],
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
