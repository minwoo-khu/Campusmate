import 'todo_model.dart';

class TodoRepo {
  final List<TodoItem> _items = [];

  List<TodoItem> list() => List.unmodifiable(_items);

  void add(TodoItem item) {
    _items.insert(0, item);
  }

  void toggle(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _items[idx].completed = !_items[idx].completed;
    }
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
  }
}

final todoRepo = TodoRepo(); // MVP용 전역
