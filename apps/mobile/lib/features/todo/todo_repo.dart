import 'package:hive/hive.dart';
import 'todo_model.dart';

class TodoRepo {
  Box<TodoItem> get _box => Hive.box<TodoItem>('todos');

  List<TodoItem> list() {
    final items = _box.values.toList();

    int rank(TodoItem t) => (t.dueAt == null) ? 1 : 0;

    items.sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra - rb;

      // 둘 다 due 있음: 가까운 날짜가 위
      final da = a.dueAt!;
      final db = b.dueAt!;
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;

      // tie-breaker: 최근 추가가 위
      return (b.key as int).compareTo(a.key as int);
    });

    return items;
  }

  Future<void> add(TodoItem item) async {
    await _box.add(item);
  }

  Future<void> toggle(TodoItem item) async {
    item.completed = !item.completed;
    await item.save();
  }

  Future<void> remove(TodoItem item) async {
    await item.delete();
  }
}

final todoRepo = TodoRepo();
