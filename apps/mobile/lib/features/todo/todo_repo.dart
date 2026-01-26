import 'package:hive/hive.dart';
import 'todo_model.dart';

class TodoRepo {
  Box<TodoItem> get _box => Hive.box<TodoItem>('todos');

  List<TodoItem> list() {
    final items = _box.values.toList();
    // 최근 추가가 위로 오게 하려면 역순/정렬
    items.sort((a, b) => b.key.compareTo(a.key)); // key(int) 기준
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
