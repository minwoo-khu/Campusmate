import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'todo_add_screen.dart';
import 'todo_model.dart';
import 'todo_repo.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  void _openAdd(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TodoAddScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<TodoItem>('todos');

    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<TodoItem> b, _) {
          final items = todoRepo.list();

          if (items.isEmpty) {
            return const Center(child: Text('No todos yet'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final t = items[i];
              final due = t.dueAt;
              final dueStr = due == null ? null : due.toLocal().toString().split(' ')[0];

              return Dismissible(
                key: ValueKey('${t.key}_${t.id}'),
                background: Container(color: Colors.red),
                onDismissed: (_) async {
                  await todoRepo.remove(t);
                },
                child: ListTile(
                  leading: Checkbox(
                    value: t.completed,
                    onChanged: (_) async {
                      await todoRepo.toggle(t);
                    },
                  ),
                  title: Text(
                    t.title,
                    style: TextStyle(
                      decoration: t.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: dueStr == null ? null : Text('Due: $dueStr'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete todo?'),
                          content: Text('"${t.title}"'),
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
                        await todoRepo.remove(t);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
