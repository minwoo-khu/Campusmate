class TodoItem {
  final String id;
  final String title;
  final DateTime? dueAt;
  bool completed;

  TodoItem({
    required this.id,
    required this.title,
    this.dueAt,
    this.completed = false,
  });
}
