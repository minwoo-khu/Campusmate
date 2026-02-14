import 'package:home_widget/home_widget.dart';

import '../features/courses/course.dart';
import '../features/todo/todo_model.dart';

class HomeWidgetService {
  HomeWidgetService._();

  // Temporarily disabled until widget UX is refreshed.
  static const bool isEnabled = false;

  static const _androidWidgetName = 'TodayWidgetProvider';
  static const _widgetLocaleCodeKey = 'widget_locale_code';

  static const widgetCompleteHost = 'todo';
  static const widgetCompletePath = '/complete';
  static const widgetNavigateHost = 'nav';
  static const widgetNavigatePath = '/tab';

  static DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  static Future<void> _refreshWidget() async {
    if (!isEnabled) return;
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }

  static int _clampedTab(int value) => value.clamp(0, 4).toInt();

  static Future<void> syncLocaleCode(String localeCode) async {
    if (!isEnabled) return;
    try {
      final normalized = localeCode.toLowerCase().startsWith('en')
          ? 'en'
          : 'ko';
      await HomeWidget.saveWidgetData<String>(_widgetLocaleCodeKey, normalized);
      await _refreshWidget();
    } catch (_) {
      // Ignore when widget host is unavailable.
    }
  }

  static Future<void> syncTodoSummary(Iterable<TodoItem> todos) async {
    if (!isEnabled) return;
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
      final primary = activeToday.isEmpty ? null : activeToday.first;

      await HomeWidget.saveWidgetData<String>(
        'widget_date',
        '${today.month}/${today.day}',
      );
      await HomeWidget.saveWidgetData<int>(
        'widget_todo_count',
        activeToday.length,
      );
      await HomeWidget.saveWidgetData<String>('widget_todo_lines', lines);
      await HomeWidget.saveWidgetData<String>(
        'widget_todo_primary_id',
        primary?.id ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_todo_primary_title',
        primary?.title ?? '',
      );
      await _refreshWidget();
    } catch (_) {
      // Ignore when widget host is unavailable.
    }
  }

  static Future<void> syncTimetableSummary(Iterable<Course> courses) async {
    if (!isEnabled) return;
    try {
      final names =
          courses
              .map((c) => c.name.trim())
              .where((name) => name.isNotEmpty)
              .toList()
            ..sort();
      final lines = names.take(3).map((name) => '- $name').join('\n');

      await HomeWidget.saveWidgetData<int>(
        'widget_timetable_count',
        names.length,
      );
      await HomeWidget.saveWidgetData<String>('widget_timetable_lines', lines);
      await _refreshWidget();
    } catch (_) {
      // Ignore when widget host is unavailable.
    }
  }

  static Future<void> syncIcsTodayCount(Iterable<DateTime> starts) async {
    if (!isEnabled) return;
    try {
      final today = _ymd(DateTime.now());
      final count = starts.where((s) => _ymd(s) == today).length;
      await HomeWidget.saveWidgetData<int>('widget_ics_count', count);
      await _refreshWidget();
    } catch (_) {
      // Ignore when widget host is unavailable.
    }
  }

  static String? extractCompleteTodoId(Uri? uri) {
    if (!isEnabled) return null;
    if (uri == null) return null;
    if (uri.host != widgetCompleteHost) return null;
    if (uri.path != widgetCompletePath) return null;

    final id = uri.queryParameters['id']?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static int? extractTabToOpen(Uri? uri) {
    if (!isEnabled) return null;
    if (uri == null) return null;
    if (uri.host != widgetNavigateHost) return null;
    if (uri.path != widgetNavigatePath) return null;

    final target = uri.queryParameters['target']?.trim().toLowerCase();
    switch (target) {
      case 'home':
        return 0;
      case 'todo':
        return 1;
      case 'calendar':
        return 2;
      case 'timetable':
        return 3;
      case 'courses':
        return 4;
      default:
        final raw = int.tryParse(target ?? '');
        if (raw == null) return null;
        return _clampedTab(raw);
    }
  }
}
