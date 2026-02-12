import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_link.dart';
import '../../app/ics_settings_screen.dart';
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

  String _monthLabel(DateTime day) => '${day.year}년 ${day.month}월';

  String _syncLabel(DateTime dt) {
    final local = dt.toLocal();
    return '${_fmtYmd(local)} ${_fmtHm(local)} 동기화';
  }

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
      setState(() {
        _loading = false;
        _message = '학교 캘린더가 연결되지 않았습니다.';
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

      setState(() {
        _icsEvents = events;
        _loading = false;
        _lastIcsSyncAt = DateTime.now();
        if (events.isEmpty) {
          _message = '연결된 캘린더에 일정이 없습니다.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = '학교 캘린더를 불러오지 못했습니다: $e';
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
        items.add(_CalItem.todo(todoItem: todo, when: due, subtitle: '오늘 마감'));
      }
    }

    for (final event in _icsEvents) {
      if (_sameYmd(event.start, day)) {
        items.add(
          _CalItem.ics(
            event: event,
            when: event.start,
            subtitle: event.allDay ? '종일' : '${_fmtHm(event.start)} 시작',
          ),
        );
      }
    }

    items.sort((a, b) => a.when.compareTo(b.when));
    return items;
  }

  Future<void> _showEventBottomSheet(_CalItem item) async {
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Chip(
                      label: Text(isTodo ? '나의 할 일' : '학교 캘린더'),
                      backgroundColor: isTodo
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFEDE9FE),
                    ),
                    if (isTodo && todo != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(todo.completed ? '완료' : '진행'),
                        backgroundColor: todo.completed
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFFDCFCE7),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${_fmtYmd(item.when)} ${_fmtHm(item.when)}',
                  style: const TextStyle(color: Color(0xFF64748B)),
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
                          label: const Text('Todo에서 보기'),
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
                          label: const Text('수정'),
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
                      label: Text(todo.completed ? '다시 진행으로' : '완료 처리'),
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
                      child: const Text('해당 날짜로 이동'),
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
    final isTodo = item.source == _Source.todo;
    final leftColor = isTodo
        ? const Color(0xFF3B82F6)
        : const Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTodo ? Colors.white : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTodo ? const Color(0xFFE2E8F0) : const Color(0xFFDDD6FE),
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
                  isTodo ? '나의 할 일' : '학교 캘린더 (ICS)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: leftColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 21 / 1.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
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
    final todoBox = Hive.box<TodoItem>('todos');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
                            style: const TextStyle(
                              fontSize: 38 / 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _moveMonth(-1),
                            icon: const Icon(Icons.chevron_left),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E7EB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _moveMonth(1),
                            icon: const Icon(Icons.chevron_right),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E7EB),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _openIcsSettings,
                            icon: const Icon(Icons.link),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E7EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            outsideTextStyle: const TextStyle(
                              color: Color(0xFFCBD5E1),
                            ),
                            markerDecoration: const BoxDecoration(
                              color: Color(0xFF8B5CF6),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            selectedDecoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF93C5FD),
                              ),
                            ),
                            selectedTextStyle: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                            ),
                            todayTextStyle: const TextStyle(
                              color: Color(0xFF1E3A8A),
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
                        '${_selectedDay.month}월 ${_selectedDay.day}일 일정',
                        style: const TextStyle(
                          fontSize: 25 / 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
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
                              ? '동기화 전'
                              : _syncLabel(_lastIcsSyncAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _loadIcs,
                        icon: const Icon(Icons.refresh, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: '동기화',
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
                          color: _message!.contains('못했습니다')
                              ? Colors.red
                              : const Color(0xFF64748B),
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
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('선택한 날짜에 일정이 없습니다.')),
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
