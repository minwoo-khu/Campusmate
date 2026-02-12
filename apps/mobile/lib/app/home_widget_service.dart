import 'package:home_widget/home_widget.dart';

import '../features/todo/todo_model.dart';

class HomeWidgetService {
  HomeWidgetService._();

  static const _androidWidgetName = 'TodayWidgetProvider';

  static DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  static Future<void> _refreshWidget() async {
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }

  static Future<void> syncTodoSummary(Iterable<TodoItem> todos) async {
    try {
      final now = DateTime.now();
      final today = _ymd(now);

      final activeToday =
          todos.where((t) {
            if (t.completed) return false;
            final due = t.dueAt;
            if (due == null) return false;
            final dueDay = _ymd(due);
            return !dueDay.isAfter(today);
          }).toList()..sort((a, b) {
            final da = a.dueAt;
            final db = b.dueAt;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });

      final lines = activeToday.take(3).map((t) => '- ${t.title}').join('\n');

      await HomeWidget.saveWidgetData<String>(
        'widget_date',
        '${today.month}/${today.day}',
      );
      await HomeWidget.saveWidgetData<int>(
        'widget_todo_count',
        activeToday.length,
      );
      await HomeWidget.saveWidgetData<String>('widget_todo_lines', lines);
      await _refreshWidget();
    } catch (_) {
      // Ignore when widget host is unavailable.
    }
  }

  static Future<void> syncIcsTodayCount(Iterable<DateTime> starts) async {
    try {
      final today = _ymd(DateTime.now());
      final count = starts.where((s) => _ymd(s) == today).length;
      await HomeWidget.saveWidgetData<int>('widget_ics_count', count);
      await _refreshWidget();
    } catch (_) {
      // Ignore when widget host is unavailable.
    }
  }
}
