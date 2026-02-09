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
    int rank(TodoItem t) => (t.dueAt == null) ? 1 : 0;
    items.sort((a, b) {
      final ra = rank(a);
      final rb = rank(b);
      if (ra != rb) return ra - rb;
      final da = a.dueAt!;
      final db = b.dueAt!;
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return (b.key as int).compareTo(a.key as int);
    });
    return items;
  }

  Future<void> _syncReminder(TodoItem item) async {
    // 완료면 무조건 취소
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

    // 기존 알림 있으면 취소 후 재예약(수정 반영)
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
    item.completed = !item.completed;
    await item.save();
    await _syncReminder(item);
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