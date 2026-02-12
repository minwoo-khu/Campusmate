import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_link.dart';
import '../../app/home_widget_service.dart';
import '../../app/ics_settings_screen.dart';
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

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _loading = false;
  String? _message;
  DateTime? _lastIcsSyncAt;
  List<IcsEvent> _icsEvents = [];

  @override
  void initState() {
    super.initState();
    _loadIcs();
  }

  String _two(int x) => x.toString().padLeft(2, '0');

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameYmd(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmtYmd(DateTime dt) => '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  String _fmtHm(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

  String _monthLabel(DateTime day) =>
      '${day.year} ${day.month.toString().padLeft(2, '0')}';

  Future<void> _openIcsSettings() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const IcsSettingsScreen()));
    if (changed == true) {
      await _loadIcs();
    }
  }

  Future<void> _loadIcs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = (prefs.getString(_prefKeyIcsUrl) ?? '').trim();

    setState(() {
      _loading = true;
      _message = null;
      _icsEvents = [];
    });

    if (url.isEmpty) {
      await HomeWidgetService.syncIcsTodayCount(const []);
      setState(() {
        _loading = false;
        _message = 'School calendar is not connected.';
      });
      return;
    }

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final events = parseIcs(resp.body)
        ..sort((a, b) => a.start.compareTo(b.start));

      await HomeWidgetService.syncIcsTodayCount(events.map((e) => e.start));

      setState(() {
        _icsEvents = events;
        _loading = false;
        _lastIcsSyncAt = DateTime.now();
        if (events.isEmpty) {
          _message = 'Connected, but no events found.';
        }
      });
    } catch (e) {
      await HomeWidgetService.syncIcsTodayCount(const []);
      setState(() {
        _loading = false;
        _message = 'Failed to load school calendar: $e';
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

  List<_CalItem> _itemsForDay(Box<TodoItem> box, DateTime day) {
    final items = <_CalItem>[];

    for (final todo in box.values) {
      final due = todo.dueAt;
      if (due != null && _sameYmd(due, day)) {
        items.add(
          _CalItem.todo(
            todoItem: todo,
            when: due,
            subtitle: 'Due ${_fmtHm(due)}',
          ),
        );
      }
    }

    for (final event in _icsEvents) {
      if (_sameYmd(event.start, day)) {
        items.add(
          _CalItem.ics(
            event: event,
            when: event.start,
            subtitle: event.allDay ? 'All day' : '${_fmtHm(event.start)} start',
          ),
        );
      }
    }

    items.sort((a, b) => a.when.compareTo(b.when));
    return items;
  }

  Future<void> _showEventBottomSheet(_CalItem item) async {
    final cm = context.cmColors;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final isTodo = item.source == _Source.todo;
        final todo = item.todo;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cm.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Chip(
                      label: Text(isTodo ? 'My Todo' : 'School ICS'),
                    ),
                    if (isTodo && todo != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(todo.completed ? 'Completed' : 'Active'),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${_fmtYmd(item.when)} ${_fmtHm(item.when)}',
                  style: TextStyle(color: cm.textTertiary),
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
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open in Todo'),
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
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
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
                        await todoRepo.toggle(todo);
                      },
                      icon: Icon(todo.completed ? Icons.undo : Icons.check),
                      label: Text(
                        todo.completed ? 'Mark active' : 'Mark completed',
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
                      child: const Text('Go to this date'),
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
                  isTodo ? 'My Todo' : 'School Calendar (ICS)',
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
                  style: TextStyle(
                    fontSize: 12,
                    color: cm.textTertiary,
                  ),
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
            final selectedItems = _itemsForDay(box, _selectedDay);

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
                              fontSize: 30,
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
                          eventLoader: (day) => _itemsForDay(box, day),
                          calendarStyle: CalendarStyle(
                            defaultTextStyle: TextStyle(color: cm.textPrimary),
                            weekendTextStyle: TextStyle(color: cm.textPrimary),
                            outsideTextStyle: TextStyle(
                              color: cm.textHint,
                            ),
                            markerDecoration: const BoxDecoration(
                              color: Color(0xFF8B5CF6),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            selectedDecoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(10),
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
                        '${_selectedDay.month}/${_selectedDay.day} Schedule',
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
                        Text(
                          _lastIcsSyncAt == null
                              ? 'Not synced'
                              : '${_fmtYmd(_lastIcsSyncAt!)} ${_fmtHm(_lastIcsSyncAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cm.textHint,
                          ),
                        ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _loadIcs,
                        icon: const Icon(Icons.refresh, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Sync',
                      ),
                    ],
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _message!.startsWith('Failed')
                              ? cm.deleteBg
                              : cm.textTertiary,
                          fontSize: 12,
                        ),
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
                                  'No events for selected date.',
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
                            separatorBuilder: (_, __) =>
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
