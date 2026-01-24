import 'package:flutter/material.dart';
import 'todo_repo.dart';
import 'todo_add_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  void _openAdd() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TodoAddScreen()),
    );
    if (changed == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = todoRepo.list();

    return Scaffold(
      body: items.isEmpty
          ? const Center(child: Text('No todos yet'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final t = items[i];
                return Dismissible(
                  key: ValueKey(t.id),
                  background: Container(color: Colors.red),
                  onDismissed: (_) {
                    setState(() => todoRepo.remove(t.id));
                  },
                  child: CheckboxListTile(
                    value: t.completed,
                    title: Text(
                      t.title,
                      style: TextStyle(
                        decoration: t.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: t.dueAt == null
                        ? null
                        : Text(
                            'Due: ${t.dueAt!.toLocal().toString().split(' ')[0]}'),
                    onChanged: (_) {
                      setState(() => todoRepo.toggle(t.id));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}
