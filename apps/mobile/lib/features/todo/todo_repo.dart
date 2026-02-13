import 'package:hive/hive.dart';

import '../../app/change_history_service.dart';
import '../../app/home_widget_service.dart';
import '../../app/notification_service.dart';
import '../../app/safety_limits.dart';
import 'todo_model.dart';

class TodoDailyLimitExceededException implements Exception {
  final DateTime day;
  final int limit;
  final int currentCount;

  TodoDailyLimitExceededException({
    required this.day,
    required this.limit,
    required this.currentCount,
  });

  @override
  String toString() =>
      'TodoDailyLimitExceededException(day: $day, limit: $limit, currentCount: $currentCount)';
}

class TodoRepo {
  Box<TodoItem> get _box => Hive.box<TodoItem>('todos');
  Box<int> get _notifBox => Hive.box<int>('notif');

  int _nextNotifId() {
    final cur = _notifBox.get('nextId') ?? 1;
    _notifBox.put('nextId', cur + 1);
    return cur;
  }

  String _normalizeTitle(String raw) {
    var text = raw.trim();
    if (text.isEmpty) {
      return 'Untitled';
    }
    if (text.length > SafetyLimits.maxTodoTitleChars) {
      text = text.substring(0, SafetyLimits.maxTodoTitleChars);
    }
    return text;
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

  DateTime _ymd(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  bool _sameYmd(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _countActiveDueForDay(DateTime day, {TodoItem? excluding}) {
    var count = 0;
    for (final item in _box.values) {
      if (item.completed) continue;

      final due = item.dueAt;
      if (due == null || !_sameYmd(due, day)) continue;

      if (excluding != null) {
        final sameKey = item.key != null && item.key == excluding.key;
        final sameId = item.id == excluding.id;
        if (sameKey || sameId) continue;
      }

      count++;
    }
    return count;
  }

  void _ensureDailyLimit(TodoItem item, {TodoItem? excluding}) {
    if (item.completed) return;

    final due = item.dueAt;
    if (due == null) return;

    final day = _ymd(due);
    final currentCount = _countActiveDueForDay(day, excluding: excluding);
    final limit = SafetyLimits.maxActiveTodosPerDay;
    if (currentCount >= limit) {
      throw TodoDailyLimitExceededException(
        day: day,
        limit: limit,
        currentCount: currentCount,
      );
    }
  }

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
      nextDue = _advance(_endOfDay(DateTime.now()), rule);
    }

    return TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: completedItem.title,
      dueAt: nextDue,
      remindAt: nextRemind,
      repeatRule: rule,
      completed: false,
      priorityLevel: completedItem.priorityLevel,
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

  Future<void> _syncHomeWidget() async {
    await HomeWidgetService.syncTodoSummary(_box.values);
  }

  Future<void> add(TodoItem item, {bool logAction = true}) async {
    item.title = _normalizeTitle(item.title);
    _ensureDailyLimit(item);
    await _box.add(item);
    await _syncReminder(item);
    await _syncHomeWidget();

    if (logAction) {
      await ChangeHistoryService.log('Todo added', detail: item.title);
    }
  }

  Future<void> toggle(TodoItem item, {bool logAction = true}) async {
    final wasCompleted = item.completed;
    item.completed = !item.completed;
    if (!item.completed) {
      try {
        _ensureDailyLimit(item, excluding: item);
      } on TodoDailyLimitExceededException {
        item.completed = wasCompleted;
        rethrow;
      }
    }
    await item.save();
    await _syncReminder(item);
    await _syncHomeWidget();

    if (logAction) {
      await ChangeHistoryService.log(
        item.completed ? 'Todo completed' : 'Todo reopened',
        detail: item.title,
      );
    }

    if (!wasCompleted && item.completed) {
      final next = _buildNextRecurringItem(item);
      if (next != null) {
        try {
          await add(next, logAction: false);
          await ChangeHistoryService.log(
            'Recurring todo scheduled',
            detail: next.title,
          );
        } on TodoDailyLimitExceededException {
          await ChangeHistoryService.log(
            'Recurring todo skipped (daily limit)',
            detail: next.title,
          );
        }
      }
    }
  }

  Future<void> update(TodoItem item, {bool logAction = true}) async {
    item.title = _normalizeTitle(item.title);
    _ensureDailyLimit(item, excluding: item);
    await item.save();
    await _syncReminder(item);
    await _syncHomeWidget();

    if (logAction) {
      await ChangeHistoryService.log('Todo updated', detail: item.title);
    }
  }

  Future<void> remove(TodoItem item, {bool logAction = true}) async {
    final nid = item.notificationId;
    if (nid != null) {
      await NotificationService.I.cancel(nid);
    }

    final title = item.title;
    await item.delete();
    await _syncHomeWidget();

    if (logAction) {
      await ChangeHistoryService.log('Todo deleted', detail: title);
    }
  }
}

final todoRepo = TodoRepo();
