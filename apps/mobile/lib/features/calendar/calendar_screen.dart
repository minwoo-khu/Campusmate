import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_link.dart';
import '../../app/center_notice.dart';
import '../../app/home_widget_service.dart';
import '../../app/ics_settings_screen.dart';
import '../../app/l10n.dart';
import '../../app/safety_limits.dart';
import '../../app/theme.dart';
import '../todo/todo_edit_screen.dart';
import '../todo/todo_model.dart';
import '../todo/todo_repo.dart';
import 'ics_parser.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _prefKeyIcsUrl = 'ics_feed_url';
  static const _prefKeyIcsCacheEvents = 'ics_cache_events_v1';
  static const _prefKeyIcsLastSuccessAt = 'ics_last_success_at_v1';
  static const _prefKeyIcsLastFailureAt = 'ics_last_failure_at_v1';
  static const _prefKeyIcsLastFailureReason = 'ics_last_failure_reason_v1';

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _loading = false;
  String? _message;
  DateTime? _lastIcsSyncAt;
  DateTime? _lastIcsFailureAt;
  String? _lastIcsFailureReason;
  List<IcsEvent> _icsEvents = [];

  @override
  void initState() {
    super.initState();
    _bootstrapIcs();
  }

  String _two(int x) => x.toString().padLeft(2, '0');

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmtYmd(DateTime dt) => '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  String _fmtHm(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

  String _monthLabel(DateTime day) =>
      '${day.year} ${day.month.toString().padLeft(2, '0')}';

  String _t(String ko, String en) => context.tr(ko, en);

  int _dayKey(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

  _DayItems _buildDayItems(Box<TodoItem> box) {
    final itemsByDay = <int, List<_CalItem>>{};
    final totalByDay = <int, int>{};

    void addItem(int key, _CalItem item) {
      totalByDay.update(key, (value) => value + 1, ifAbsent: () => 1);
      final bucket = itemsByDay.putIfAbsent(key, () => <_CalItem>[]);
      if (bucket.length < SafetyLimits.maxCalendarItemsPerDay) {
        bucket.add(item);
      }
    }

    for (final todo in box.values) {
      if (todo.completed) continue;
      final due = todo.dueAt;
      if (due == null) continue;

      addItem(
        _dayKey(due),
        _CalItem.todo(
          todoItem: todo,
          when: due,
          subtitle: _t('${_fmtHm(due)} due', 'Due ${_fmtHm(due)}'),
        ),
      );
    }

    for (final event in _icsEvents) {
      addItem(
        _dayKey(event.start),
        _CalItem.ics(
          event: event,
          when: event.start,
          subtitle: event.allDay
              ? _t('All day', 'All day')
              : _t(
                  '${_fmtHm(event.start)} start',
                  '${_fmtHm(event.start)} start',
                ),
        ),
      );
    }

    for (final bucket in itemsByDay.values) {
      bucket.sort((a, b) => a.when.compareTo(b.when));
    }

    final hiddenCountByDay = <int, int>{};
    totalByDay.forEach((dayKey, total) {
      final shown = itemsByDay[dayKey]?.length ?? 0;
      final hidden = total - shown;
      if (hidden > 0) {
        hiddenCountByDay[dayKey] = hidden;
      }
    });

    return _DayItems(
      itemsByDay: itemsByDay,
      hiddenCountByDay: hiddenCountByDay,
    );
  }

  List<_CalItem> _itemsForDay(_DayItems dayItems, DateTime day) {
    final key = _dayKey(day);
    return dayItems.itemsByDay[key] ?? const [];
  }

  List<_CalItem> _markerItemsForDay(_DayItems dayItems, DateTime day) {
    final items = _itemsForDay(dayItems, day);
    if (items.length <= SafetyLimits.maxCalendarMarkerItemsPerDay) {
      return items;
    }
    return items.sublist(0, SafetyLimits.maxCalendarMarkerItemsPerDay);
  }

  int _hiddenItemCountForDay(_DayItems dayItems, DateTime day) {
    return dayItems.hiddenCountByDay[_dayKey(day)] ?? 0;
  }

  void _showDailyLimitMessage(TodoDailyLimitExceededException e) {
    if (!mounted) return;
    CenterNotice.show(
      context,
      message: _t(
        '하루 할 일 한도(${e.limit}개)를 초과했습니다.',
        'Daily todo limit reached (${e.limit}).',
      ),
      error: true,
    );
  }

  Future<void> _openIcsSettings() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const IcsSettingsScreen()));
    if (changed == true) {
      await _loadIcs();
    }
  }

  Future<void> _bootstrapIcs() async {
    await _restoreCachedIcs();
    await _loadIcs();
  }

  DateTime? _parseIsoLocal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Uri? _validatedIcsUri(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) return null;
    return uri;
  }

  String _encodeCacheEvents(List<IcsEvent> events) {
    final payload = events
        .map(
          (e) => {
            'uid': e.uid,
            'summary': e.summary,
            'start': e.start.toIso8601String(),
            'end': e.end?.toIso8601String(),
            'allDay': e.allDay,
          },
        )
        .toList();
    return jsonEncode(payload);
  }

  List<IcsEvent> _decodeCacheEvents(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final events = <IcsEvent>[];
      for (final item in decoded) {
        if (item is! Map) continue;

        final uid = (item['uid'] as String?)?.trim() ?? '';
        final summary = (item['summary'] as String?)?.trim() ?? '';
        final startRaw = item['start'] as String?;
        final endRaw = item['end'] as String?;
        final allDay = item['allDay'] == true;
        final start = _parseIsoLocal(startRaw);
        if (start == null) continue;

        events.add(
          IcsEvent(
            uid: uid.isEmpty ? '${summary}_${start.toIso8601String()}' : uid,
            summary: summary.isEmpty ? '(No title)' : summary,
            start: start,
            end: _parseIsoLocal(endRaw),
            allDay: allDay,
          ),
        );
      }
      events.sort((a, b) => a.start.compareTo(b.start));
      return events;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _restoreCachedIcs() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedEvents = _decodeCacheEvents(
      prefs.getString(_prefKeyIcsCacheEvents),
    );

    if (!mounted) return;
    setState(() {
      _icsEvents = cachedEvents;
      _lastIcsSyncAt = _parseIsoLocal(
        prefs.getString(_prefKeyIcsLastSuccessAt),
      );
      _lastIcsFailureAt = _parseIsoLocal(
        prefs.getString(_prefKeyIcsLastFailureAt),
      );
      _lastIcsFailureReason = prefs.getString(_prefKeyIcsLastFailureReason);
    });
  }

  Future<void> _saveCacheSuccess({
    required SharedPreferences prefs,
    required List<IcsEvent> events,
    required DateTime now,
  }) async {
    await prefs.setString(_prefKeyIcsCacheEvents, _encodeCacheEvents(events));
    await prefs.setString(_prefKeyIcsLastSuccessAt, now.toIso8601String());
    await prefs.remove(_prefKeyIcsLastFailureAt);
    await prefs.remove(_prefKeyIcsLastFailureReason);
  }

  Future<void> _saveCacheFailure({
    required SharedPreferences prefs,
    required DateTime now,
    required String reason,
  }) async {
    await prefs.setString(_prefKeyIcsLastFailureAt, now.toIso8601String());
    await prefs.setString(_prefKeyIcsLastFailureReason, reason);
  }

  Future<void> _clearCache(SharedPreferences prefs) async {
    await prefs.remove(_prefKeyIcsCacheEvents);
    await prefs.remove(_prefKeyIcsLastSuccessAt);
    await prefs.remove(_prefKeyIcsLastFailureAt);
    await prefs.remove(_prefKeyIcsLastFailureReason);
  }

  Future<void> _loadIcs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = (prefs.getString(_prefKeyIcsUrl) ?? '').trim();

    setState(() {
      _loading = true;
      _message = null;
    });

    if (url.isEmpty) {
      await _clearCache(prefs);
      await HomeWidgetService.syncIcsTodayCount(const []);
      setState(() {
        _loading = false;
        _icsEvents = [];
        _lastIcsSyncAt = null;
        _lastIcsFailureAt = null;
        _lastIcsFailureReason = null;
        _message = _t(
          '학교 캘린더가 연결되지 않았습니다.',
          'School calendar is not connected.',
        );
      });
      return;
    }
    final uri = _validatedIcsUri(url);
    if (uri == null) {
      final now = DateTime.now();
      final reason = 'ICS URL must use HTTPS.';
      await _saveCacheFailure(prefs: prefs, now: now, reason: reason);
      await HomeWidgetService.syncIcsTodayCount(
        _icsEvents.map((event) => event.start),
      );
      setState(() {
        _loading = false;
        _lastIcsFailureAt = now;
        _lastIcsFailureReason = reason;
        _message = _t(
          'ICS URL 형식이 올바르지 않습니다. HTTPS URL을 사용하세요.',
          'Invalid ICS URL. Use an HTTPS URL.',
        );
      });
      return;
    }

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      final finalUri = resp.request?.url;
      if (finalUri != null &&
          (finalUri.scheme.toLowerCase() != 'https' || finalUri.host.isEmpty)) {
        throw Exception('Redirected to non-HTTPS URL');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      if (resp.bodyBytes.length > SafetyLimits.maxIcsPayloadBytes) {
        throw Exception(
          'ICS payload too large (${resp.bodyBytes.length} bytes, limit ${SafetyLimits.maxIcsPayloadBytes})',
        );
      }

      final parsed = parseIcs(resp.body)
        ..sort((a, b) => a.start.compareTo(b.start));
      final truncated = parsed.length > SafetyLimits.maxIcsEvents;
      final events = truncated
          ? parsed.sublist(0, SafetyLimits.maxIcsEvents)
          : parsed;
      final now = DateTime.now();

      await HomeWidgetService.syncIcsTodayCount(events.map((e) => e.start));
      await _saveCacheSuccess(prefs: prefs, events: events, now: now);

      setState(() {
        _icsEvents = events;
        _loading = false;
        _lastIcsSyncAt = now;
        _lastIcsFailureAt = null;
        _lastIcsFailureReason = null;
        if (events.isEmpty) {
          _message = _t('연결되었지만 일정이 없습니다.', 'Connected, but no events found.');
        } else if (truncated) {
          _message = _t(
            '일정이 많아 일부만 표시합니다. (${events.length}개)',
            'Calendar is large. Showing first ${events.length} events.',
          );
        }
      });
    } catch (e) {
      final now = DateTime.now();
      await _saveCacheFailure(prefs: prefs, now: now, reason: '$e');
      await HomeWidgetService.syncIcsTodayCount(
        _icsEvents.map((event) => event.start),
      );

      setState(() {
        _loading = false;
        _lastIcsFailureAt = now;
        _lastIcsFailureReason = '$e';
        _message = _icsEvents.isEmpty
            ? _t('학교 캘린더를 불러오지 못했습니다: $e', 'Failed to load school calendar: $e')
            : _t(
                '동기화 실패. 캐시된 일정을 표시합니다.',
                'Sync failed. Showing cached events.',
              );
      });
    }
  }

  void _moveMonth(int offset) {
    final moved = DateTime(_focusedDay.year, _focusedDay.month + offset, 1);
    setState(() {
      _focusedDay = moved;
      _selectedDay = moved;
    });
  }

  Future<void> _showEventBottomSheet(_CalItem item) async {
    final cm = context.cmColors;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cm.cardBg,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final isTodo = item.source == _Source.todo;
        final todo = item.todo;
        final sourceColor = isTodo ? cm.navActive : const Color(0xFF8B5CF6);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cm.chipBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cm.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isTodo ? cm.todoEventBg : cm.icsEventBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isTodo
                              ? cm.todoEventBorder
                              : cm.icsEventBorder,
                        ),
                      ),
                      child: Text(
                        isTodo
                            ? _t('내 할 일', 'My Todo')
                            : _t('학교 ICS', 'School ICS'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sourceColor,
                        ),
                      ),
                    ),
                    if (isTodo && todo != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: todo.completed
                              ? cm.tileCompletedBg
                              : cm.inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cm.cardBorder),
                        ),
                        child: Text(
                          todo.completed
                              ? _t('완료', 'Completed')
                              : _t('진행 중', 'Active'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: todo.completed ? cm.textHint : cm.navActive,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cm.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cm.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: cm.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmtYmd(item.when)} ${_fmtHm(item.when)}',
                        style: TextStyle(
                          color: cm.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isTodo && todo != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            AppLink.openTodo(todo.id);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cm.textPrimary,
                            side: BorderSide(color: cm.chipBorder),
                            backgroundColor: cm.inputBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(_t('할 일에서 열기', 'Open in Todo')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            if (!mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TodoEditScreen(item: todo),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: cm.navActive,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.edit),
                          label: Text(_t('수정', 'Edit')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        try {
                          await todoRepo.toggle(todo);
                        } on TodoDailyLimitExceededException catch (e) {
                          _showDailyLimitMessage(e);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: cm.navActive,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(todo.completed ? Icons.undo : Icons.check),
                      label: Text(
                        todo.completed
                            ? _t('진행으로 변경', 'Mark active')
                            : _t('완료로 변경', 'Mark completed'),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedDay = _ymd(item.when);
                          _focusedDay = _ymd(item.when);
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: cm.navActive,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_t('이 날짜로 이동', 'Go to this date')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(_CalItem item) {
    final cm = context.cmColors;
    final isTodo = item.source == _Source.todo;
    final leftColor = isTodo ? cm.navActive : const Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTodo ? cm.todoEventBg : cm.icsEventBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTodo ? cm.todoEventBorder : cm.icsEventBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: leftColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTodo
                      ? _t('내 할 일', 'My Todo')
                      : _t('학교 캘린더 (ICS)', 'School Calendar (ICS)'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: leftColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cm.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(fontSize: 12, color: cm.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final todoBox = Hive.box<TodoItem>('todos');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cm.scaffoldBg,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: todoBox.listenable(),
          builder: (context, Box<TodoItem> box, _) {
            final dayItems = _buildDayItems(box);
            final selectedItems = _itemsForDay(dayItems, _selectedDay);
            final hiddenItemCount = _hiddenItemCountForDay(
              dayItems,
              _selectedDay,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            _monthLabel(_focusedDay),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: cm.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _moveMonth(-1),
                            icon: const Icon(Icons.chevron_left),
                            style: IconButton.styleFrom(
                              backgroundColor: cm.iconButtonBg,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _moveMonth(1),
                            icon: const Icon(Icons.chevron_right),
                            style: IconButton.styleFrom(
                              backgroundColor: cm.iconButtonBg,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _openIcsSettings,
                            icon: const Icon(Icons.link),
                            style: IconButton.styleFrom(
                              backgroundColor: cm.iconButtonBg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                        decoration: BoxDecoration(
                          color: cm.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cm.cardBorder),
                        ),
                        child: TableCalendar<_CalItem>(
                          firstDay: DateTime.utc(2000, 1, 1),
                          lastDay: DateTime.utc(2100, 12, 31),
                          focusedDay: _focusedDay,
                          headerVisible: false,
                          selectedDayPredicate: (day) =>
                              isSameDay(day, _selectedDay),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          eventLoader: (day) =>
                              _markerItemsForDay(dayItems, day),
                          calendarStyle: CalendarStyle(
                            defaultTextStyle: TextStyle(color: cm.textPrimary),
                            weekendTextStyle: TextStyle(color: cm.textPrimary),
                            outsideTextStyle: TextStyle(color: cm.textHint),
                            markerDecoration: const BoxDecoration(
                              color: Color(0xFF8B5CF6),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFFE0E7FF),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFFDBEAFE),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFF93C5FD),
                              ),
                            ),
                            selectedTextStyle: TextStyle(
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                            ),
                            todayTextStyle: TextStyle(
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Text(
                        context.tr(
                          '${_selectedDay.month}/${_selectedDay.day} 일정',
                          '${_selectedDay.month}/${_selectedDay.day} Schedule',
                        ),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: cm.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (_loading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _lastIcsSyncAt == null
                                  ? context.tr(
                                      '최근 성공: 없음',
                                      'Last success: none',
                                    )
                                  : context.tr(
                                      '최근 성공: ${_fmtYmd(_lastIcsSyncAt!)} ${_fmtHm(_lastIcsSyncAt!)}',
                                      'Last success: ${_fmtYmd(_lastIcsSyncAt!)} ${_fmtHm(_lastIcsSyncAt!)}',
                                    ),
                              style: TextStyle(
                                fontSize: 11,
                                color: cm.textHint,
                              ),
                            ),
                            if (_lastIcsFailureAt != null)
                              Text(
                                context.tr(
                                  '최근 실패: ${_fmtYmd(_lastIcsFailureAt!)} ${_fmtHm(_lastIcsFailureAt!)}',
                                  'Last failure: ${_fmtYmd(_lastIcsFailureAt!)} ${_fmtHm(_lastIcsFailureAt!)}',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cm.deleteBg,
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _loadIcs,
                        icon: const Icon(Icons.refresh, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: context.tr('동기화', 'Sync'),
                      ),
                    ],
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _message!,
                            style: TextStyle(
                              color: _lastIcsFailureAt != null
                                  ? cm.deleteBg
                                  : cm.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          if (_lastIcsFailureReason != null &&
                              _lastIcsFailureAt != null &&
                              kDebugMode)
                            Text(
                              context.tr(
                                '원인: ${_lastIcsFailureReason!}',
                                'Reason: ${_lastIcsFailureReason!}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cm.textHint,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (hiddenItemCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.tr(
                          '표시 제한으로 $hiddenItemCount개 항목이 숨겨졌습니다.',
                          '$hiddenItemCount items are hidden by safety limit.',
                        ),
                        style: TextStyle(fontSize: 12, color: cm.textHint),
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadIcs,
                    child: selectedItems.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  context.tr(
                                    '선택한 날짜의 일정이 없습니다.',
                                    'No events for selected date.',
                                  ),
                                  style: TextStyle(color: cm.textTertiary),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            itemBuilder: (_, i) {
                              final item = selectedItems[i];
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _showEventBottomSheet(item),
                                child: _buildEventCard(item),
                              );
                            },
                            separatorBuilder: (_, separatorIndex) =>
                                const SizedBox(height: 10),
                            itemCount: selectedItems.length,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _Source { todo, ics }

class _DayItems {
  final Map<int, List<_CalItem>> itemsByDay;
  final Map<int, int> hiddenCountByDay;

  const _DayItems({required this.itemsByDay, required this.hiddenCountByDay});
}

class _CalItem {
  final String title;
  final DateTime when;
  final _Source source;
  final String subtitle;
  final bool done;
  final TodoItem? todo;
  final IcsEvent? ics;

  _CalItem.todo({
    required TodoItem todoItem,
    required this.when,
    required this.subtitle,
  }) : title = todoItem.title,
       source = _Source.todo,
       done = todoItem.completed,
       todo = todoItem,
       ics = null;

  _CalItem.ics({
    required IcsEvent event,
    required this.when,
    required this.subtitle,
  }) : title = event.summary,
       source = _Source.ics,
       done = false,
       todo = null,
       ics = event;
}
