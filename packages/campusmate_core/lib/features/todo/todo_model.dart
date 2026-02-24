import 'package:hive/hive.dart';

part 'todo_model.g.dart';

enum TodoRepeat { none, daily, weekly }

extension TodoRepeatX on TodoRepeat {
  String get storageValue {
    switch (this) {
      case TodoRepeat.none:
        return 'none';
      case TodoRepeat.daily:
        return 'daily';
      case TodoRepeat.weekly:
        return 'weekly';
    }
  }

  String get label {
    switch (this) {
      case TodoRepeat.none:
        return 'None';
      case TodoRepeat.daily:
        return 'Daily';
      case TodoRepeat.weekly:
        return 'Weekly';
    }
  }

  static TodoRepeat fromStorage(String? value) {
    switch (value) {
      case 'daily':
        return TodoRepeat.daily;
      case 'weekly':
        return TodoRepeat.weekly;
      default:
        return TodoRepeat.none;
    }
  }
}

enum TodoPriority { none, low, medium, high }

extension TodoPriorityX on TodoPriority {
  String get storageValue {
    switch (this) {
      case TodoPriority.none:
        return 'none';
      case TodoPriority.low:
        return 'low';
      case TodoPriority.medium:
        return 'medium';
      case TodoPriority.high:
        return 'high';
    }
  }

  String get label {
    switch (this) {
      case TodoPriority.none:
        return 'None';
      case TodoPriority.low:
        return 'Low';
      case TodoPriority.medium:
        return 'Medium';
      case TodoPriority.high:
        return 'High';
    }
  }

  static TodoPriority fromStorage(String? value) {
    switch (value) {
      case 'low':
        return TodoPriority.low;
      case 'medium':
        return TodoPriority.medium;
      case 'high':
        return TodoPriority.high;
      default:
        return TodoPriority.none;
    }
  }
}

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
  int? remindAtMillis;

  @HiveField(5)
  int? notificationId;

  @HiveField(6)
  String repeat;

  @HiveField(7)
  String priority;

  TodoItem({
    required this.id,
    required this.title,
    DateTime? dueAt,
    this.completed = false,
    DateTime? remindAt,
    this.notificationId,
    TodoRepeat repeatRule = TodoRepeat.none,
    TodoPriority priorityLevel = TodoPriority.none,
  }) : dueAtMillis = dueAt?.millisecondsSinceEpoch,
       remindAtMillis = remindAt?.millisecondsSinceEpoch,
       repeat = repeatRule.storageValue,
       priority = priorityLevel.storageValue;

  DateTime? get dueAt => dueAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(dueAtMillis!);

  set dueAt(DateTime? value) => dueAtMillis = value?.millisecondsSinceEpoch;

  DateTime? get remindAt => remindAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(remindAtMillis!);

  set remindAt(DateTime? value) =>
      remindAtMillis = value?.millisecondsSinceEpoch;

  TodoRepeat get repeatRule => TodoRepeatX.fromStorage(repeat);

  set repeatRule(TodoRepeat value) => repeat = value.storageValue;

  TodoPriority get priorityLevel => TodoPriorityX.fromStorage(priority);

  set priorityLevel(TodoPriority value) => priority = value.storageValue;
}
