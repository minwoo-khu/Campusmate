import 'package:flutter/material.dart';
import '../todo/todo_repo.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final todosWithDue = todoRepo
        .list()
        .where((t) => t.dueAt != null)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // ✅ Todo due-date 리스트
            Expanded(
              child: todosWithDue.isEmpty
                  ? const Center(child: Text('No due dates yet'))
                  : ListView.separated(
                      itemCount: todosWithDue.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = todosWithDue[i];
                        final dateStr =
                            t.dueAt!.toLocal().toString().split(' ')[0];

                        return ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(t.title),
                          subtitle: Text('Due: $dateStr'),
                          trailing: t.completed
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () {
                            // 1차에서는 그냥 안내만
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Todo 편집은 2차에서 추가'),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 8),

            // ✅ 다음 단계(ICS) 안내 버튼(지금은 UI만)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ICS 피드 연결은 다음 커밋에서!')),
                  );
                },
                icon: const Icon(Icons.link),
                label: const Text('Connect school calendar (ICS)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
