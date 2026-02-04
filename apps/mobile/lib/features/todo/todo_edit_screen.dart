import 'package:flutter/material.dart';
import 'todo_model.dart';

class TodoEditScreen extends StatefulWidget {
  final TodoItem item;
  const TodoEditScreen({super.key, required this.item});

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  late final TextEditingController _controller;
  DateTime? _dueAt;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.title);
    _dueAt = widget.item.dueAt;
    _completed = widget.item.completed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now;

    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime(now.year + 5),
      initialDate: DateTime(initial.year, initial.month, initial.day),
    );

    if (picked != null) {
      setState(() => _dueAt = picked);
    }
  }

  Future<void> _clearDate() async {
    setState(() => _dueAt = null);
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    widget.item.title = title;
    widget.item.dueAt = _dueAt;
    widget.item.completed = _completed;
    await widget.item.save();

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete todo?'),
        content: Text('"${widget.item.title}"'),
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
      await widget.item.delete();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueText = _dueAt == null
        ? 'No due date'
        : 'Due: ${_dueAt!.toLocal().toString().split(' ')[0]}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Todo'),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _completed,
              onChanged: (v) => setState(() => _completed = v),
              title: const Text('Completed'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(dueText)),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Pick date'),
                ),
                TextButton(
                  onPressed: _dueAt == null ? null : _clearDate,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
