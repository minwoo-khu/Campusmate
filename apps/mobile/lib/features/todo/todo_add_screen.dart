import 'package:flutter/material.dart';
import 'todo_model.dart';
import 'todo_repo.dart';
import 'package:uuid/uuid.dart';

class TodoAddScreen extends StatefulWidget {
  final DateTime? initialDueAt;
  const TodoAddScreen({super.key, this.initialDueAt});

  @override
  State<TodoAddScreen> createState() => _TodoAddScreenState();
}


class _TodoAddScreenState extends State<TodoAddScreen> {
  final _controller = TextEditingController();
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _dueAt = widget.initialDueAt;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
    );
    if (picked != null) {
      setState(() => _dueAt = picked);
    }
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    await todoRepo.add(
      TodoItem(
        id: const Uuid().v4(),
        title: title,
        dueAt: _dueAt,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Todo')),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dueAt == null
                        ? 'No due date'
                        : 'Due: ${_dueAt!.toLocal().toString().split(' ')[0]}',
                  ),
                ),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Pick date'),
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
