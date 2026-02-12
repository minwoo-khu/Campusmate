import 'package:hive/hive.dart';

import '../../app/notification_service.dart';
import 'todo_model.dart';

class TodoRepo {
  Box<TodoItem> get _box => Hive.box<TodoItem>('todos');
  Box<int> get _notifBox => Hive.box<int>('notif');

  int _nextNotifId() {
    final cur = _notifBox.get('nextId') ?? 1;
    _notifBox.put('nextId', cur + 1);
    return cur;
  }

  List<TodoItem> list() {
    final items = _box.values.toList();
    items.sort((a, b) {
      final aHasDue = a.dueAt != null;
      final bHasDue = b.dueAt != null;
      if (aHasDue != bHasDue) {
        return aHasDue ? -1 : 1;
      }

      if (aHasDue && bHasDue) {
        final cmp = a.dueAt!.compareTo(b.dueAt!);
        if (cmp != 0) return cmp;
      }

      return (b.key as int).compareTo(a.key as int);
    });
    return items;
  }

  DateTime _advance(DateTime base, TodoRepeat rule) {
    switch (rule) {
      case TodoRepeat.daily:
        return base.add(const Duration(days: 1));
      case TodoRepeat.weekly:
        return base.add(const Duration(days: 7));
      case TodoRepeat.none:
        return base;
    }
  }

  DateTime _endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59);

  TodoItem? _buildNextRecurringItem(TodoItem completedItem) {
    final rule = completedItem.repeatRule;
    if (rule == TodoRepeat.none) return null;

    final due = completedItem.dueAt;
    final remind = completedItem.remindAt;

    DateTime? nextDue;
    DateTime? nextRemind;

    if (due != null) {
      nextDue = _advance(due, rule);
      if (remind != null) {
        final lead = due.difference(remind);
        nextRemind = nextDue.subtract(lead);
        if (nextRemind.isAfter(nextDue)) {
          nextRemind = nextDue;
        }
      }
    } else if (remind != null) {
      nextRemind = _advance(remind, rule);
    } else {
      // Recurring todos without time anchors are scheduled from today.
      nextDue = _advance(_endOfDay(DateTime.now()), rule);
    }

    return TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: completedItem.title,
      dueAt: nextDue,
      remindAt: nextRemind,
      repeatRule: rule,
      completed: false,
    );
  }

  Future<void> _syncReminder(TodoItem item) async {
    if (item.completed) {
      final nid = item.notificationId;
      if (nid != null) {
        await NotificationService.I.cancel(nid);
        item.notificationId = null;
        await item.save();
      }
      return;
    }

    final remindAt = item.remindAt;
    if (remindAt == null) {
      final nid = item.notificationId;
      if (nid != null) {
        await NotificationService.I.cancel(nid);
        item.notificationId = null;
        await item.save();
      }
      return;
    }

    if (item.notificationId != null) {
      await NotificationService.I.cancel(item.notificationId!);
    }

    final newId = _nextNotifId();
    item.notificationId = newId;
    await item.save();

    await NotificationService.I.scheduleTodo(
      notificationId: newId,
      todoId: item.id,
      title: item.title,
      remindAt: remindAt,
    );
  }

  Future<void> add(TodoItem item) async {
    await _box.add(item);
    await _syncReminder(item);
  }

  Future<void> toggle(TodoItem item) async {
    final wasCompleted = item.completed;
    item.completed = !item.completed;
    await item.save();
    await _syncReminder(item);

    if (!wasCompleted && item.completed) {
      final next = _buildNextRecurringItem(item);
      if (next != null) {
        await add(next);
      }
    }
  }

  Future<void> update(TodoItem item) async {
    await item.save();
    await _syncReminder(item);
  }

  Future<void> remove(TodoItem item) async {
    final nid = item.notificationId;
    if (nid != null) {
      await NotificationService.I.cancel(nid);
    }
    await item.delete();
  }
}

final todoRepo = TodoRepo();
