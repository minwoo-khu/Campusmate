import 'package:hive/hive.dart';

part 'todo_model.g.dart';

@HiveType(typeId: 1)
class TodoItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int? dueAtMillis; // DateTime을 millis로 저장

  @HiveField(3)
  bool completed;

  TodoItem({
    required this.id,
    required this.title,
    DateTime? dueAt,
    this.completed = false,
  }) : dueAtMillis = dueAt?.millisecondsSinceEpoch;

  DateTime? get dueAt =>
      dueAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAtMillis!);

  set dueAt(DateTime? v) {
    dueAtMillis = v?.millisecondsSinceEpoch;
  }
}
