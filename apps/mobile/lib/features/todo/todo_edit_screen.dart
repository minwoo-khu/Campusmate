import 'package:flutter/material.dart';

import 'todo_model.dart';
import 'todo_repo.dart';

class TodoEditScreen extends StatefulWidget {
  final TodoItem item;

  const TodoEditScreen({super.key, required this.item});

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  late final TextEditingController _titleController;

  DateTime? _dueAt;
  DateTime? _remindAt;
  TodoRepeat _repeat = TodoRepeat.none;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _dueAt = widget.item.dueAt;
    _remindAt = widget.item.remindAt;
    _repeat = widget.item.repeatRule;
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
          const SnackBar(content: Text('Reminder must be before due time.')),
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
    widget.item.repeatRule = _repeat;

    await todoRepo.update(widget.item);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    await todoRepo.remove(widget.item);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _dueAt == null ? 'None' : _fmtDateTime(_dueAt!);
    final remindText = _remindAt == null ? 'None' : _fmtDateTime(_remindAt!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Todo'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Update todo title',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Due (optional)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Due: $dueText')),
              TextButton(
                onPressed: _pickDueDate,
                child: const Text('Pick date'),
              ),
              TextButton(
                onPressed: _dueAt == null ? null : _clearDueDate,
                child: const Text('Clear'),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Reminder (optional)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Reminder: $remindText')),
              TextButton(
                onPressed: _pickReminder,
                child: const Text('Pick time'),
              ),
              TextButton(
                onPressed: _remindAt == null ? null : _clearReminder,
                child: const Text('Clear'),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text('Repeat', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<TodoRepeat>(
            initialValue: _repeat,
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
              setState(() => _repeat = value);
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
