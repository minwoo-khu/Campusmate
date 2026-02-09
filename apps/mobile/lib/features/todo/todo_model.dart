import 'package:hive/hive.dart';

part 'todo_model.g.dart';

@HiveType(typeId: 1)
class TodoItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int? dueAtMillis;

  @HiveField(3)
  bool completed;

  @HiveField(4)
  int? remindAtMillis; // DateTime millis

  @HiveField(5)
  int? notificationId; // 예약된 알림 id

  TodoItem({
    required this.id,
    required this.title,
    DateTime? dueAt,
    this.completed = false,
    DateTime? remindAt,
    this.notificationId,
  })  : dueAtMillis = dueAt?.millisecondsSinceEpoch,
        remindAtMillis = remindAt?.millisecondsSinceEpoch;

  DateTime? get dueAt =>
      dueAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAtMillis!);

  set dueAt(DateTime? v) => dueAtMillis = v?.millisecondsSinceEpoch;

  DateTime? get remindAt =>
      remindAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(remindAtMillis!);

  set remindAt(DateTime? v) => remindAtMillis = v?.millisecondsSinceEpoch;
}
