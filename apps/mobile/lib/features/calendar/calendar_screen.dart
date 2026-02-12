import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/app_link.dart';
import '../../app/ics_settings_screen.dart';
import '../todo/todo_add_screen.dart';
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
  CalendarFormat _format = CalendarFormat.month;

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

  String _fmtSyncLabel(DateTime dt) {
    final local = dt.toLocal();
    return '${_fmtYmd(local)} ${_fmtHm(local)}';
  }

  String _eventTimeLabel(_CalItem item) {
    if (item.source == _Source.ics && item.ics?.allDay == true) {
      return '${_fmtYmd(item.when)} (All day)';
    }
    return '${_fmtYmd(item.when)} ${_fmtHm(item.when)}';
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
        _message = 'No school calendar connected yet.';
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
          _message = 'School calendar connected, but no events found.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = 'Failed to load school calendar: $e';
      });
    }
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
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Chip(label: Text(isTodo ? 'TODO' : 'SCHOOL')),
                    const SizedBox(width: 8),
                    if (isTodo && todo != null)
                      Chip(
                        label: Text(todo.completed ? 'Completed' : 'Active'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('When: ${_eventTimeLabel(item)}'),
                if (isTodo && todo != null) ...[
                  const SizedBox(height: 6),
                  Text('Repeat: ${todo.repeatRule.label}'),
                ],
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
                        todo.completed ? 'Mark as active' : 'Mark complete',
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          final day = _ymd(item.when);
                          _selectedDay = day;
                          _focusedDay = day;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Go to date'),
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

  Widget _buildTodayPanel(Box<TodoItem> box) {
    final now = DateTime.now();
    final today = _ymd(now);
    final tomorrow = today.add(const Duration(days: 1));

    final icsToday = _icsEvents.where((e) => _sameYmd(e.start, today)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final dueSoon = <TodoItem>[];
    for (final t in box.values) {
      final due = t.dueAt;
      if (due == null) continue;
      if (_sameYmd(due, today) || _sameYmd(due, tomorrow)) {
        dueSoon.add(t);
      }
    }

    dueSoon.sort((a, b) {
      final ca = a.completed ? 1 : 0;
      final cb = b.completed ? 1 : 0;
      if (ca != cb) return ca - cb;
      return a.dueAt!.compareTo(b.dueAt!);
    });

    final icsTop = icsToday.take(3).toList();
    final todoTop = dueSoon.take(3).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Today',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtYmd(today),
                  style: const TextStyle(color: Colors.black54),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDay = today;
                      _focusedDay = today;
                    });
                  },
                  child: const Text('View'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.checklist, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Todo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${dueSoon.length}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (todoTop.isEmpty)
              const Text('No due soon', style: TextStyle(color: Colors.black54))
            else
              ...todoTop.map((t) {
                final due = t.dueAt!;
                final isTomorrow = _sameYmd(due, tomorrow);
                final when =
                    '${isTomorrow ? 'Tomorrow' : 'Today'} ${_fmtHm(due)}';

                final item = _CalItem.todo(
                  todoItem: t,
                  when: due,
                  subtitle: when,
                );

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    t.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: t.completed ? Colors.green : null,
                  ),
                  title: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(when),
                  onTap: () => _showEventBottomSheet(item),
                );
              }),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'School',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${icsToday.length}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (icsTop.isEmpty)
              const Text(
                'No school events today',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...icsTop.map((e) {
                final when = e.allDay ? 'All day' : _fmtHm(e.start);
                final item = _CalItem.ics(
                  event: e,
                  when: e.start,
                  subtitle: when,
                );

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note, size: 20),
                  title: Text(
                    e.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(when),
                  onTap: () => _showEventBottomSheet(item),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todoBox = Hive.box<TodoItem>('todos');

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TodoAddScreen(initialDueAt: _selectedDay),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadIcs,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Calendar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _openIcsSettings,
                    icon: const Icon(Icons.link),
                    tooltip: 'School calendar (ICS)',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _loadIcs,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _lastIcsSyncAt == null
                              ? 'School calendar not synced yet'
                              : 'Last sync: ${_fmtSyncLabel(_lastIcsSyncAt!)}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_message != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _message!.startsWith('Failed')
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ),
                    if (_message!.startsWith('Failed'))
                      TextButton(
                        onPressed: _loadIcs,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: todoBox.listenable(),
                  builder: (context, Box<TodoItem> box, _) {
                    List<_CalItem> itemsForDay(DateTime day) {
                      final items = <_CalItem>[];

                      for (final t in box.values) {
                        final due = t.dueAt;
                        if (due != null && _sameYmd(due, day)) {
                          items.add(
                            _CalItem.todo(
                              todoItem: t,
                              when: due,
                              subtitle: 'Due',
                            ),
                          );
                        }
                      }

                      for (final e in _icsEvents) {
                        if (_sameYmd(e.start, day)) {
                          items.add(
                            _CalItem.ics(
                              event: e,
                              when: e.start,
                              subtitle: e.allDay ? 'All day' : 'School',
                            ),
                          );
                        }
                      }

                      items.sort((a, b) => a.when.compareTo(b.when));
                      return items;
                    }

                    final selectedItems = itemsForDay(_selectedDay);

                    return Column(
                      children: [
                        _buildTodayPanel(box),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: TableCalendar<_CalItem>(
                              firstDay: DateTime.utc(2000, 1, 1),
                              lastDay: DateTime.utc(2100, 12, 31),
                              focusedDay: _focusedDay,
                              calendarFormat: _format,
                              selectedDayPredicate: (day) =>
                                  isSameDay(day, _selectedDay),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              onFormatChanged: (format) {
                                setState(() => _format = format);
                              },
                              eventLoader: itemsForDay,
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selected: ${_fmtYmd(_selectedDay)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: selectedItems.isEmpty
                              ? const Center(
                                  child: Text('No events on this day'),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 120),
                                  itemCount: selectedItems.length,
                                  itemBuilder: (_, i) {
                                    final item = selectedItems[i];
                                    final tag = item.source == _Source.todo
                                        ? 'TODO'
                                        : 'SCHOOL';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Card(
                                        child: ListTile(
                                          leading: item.source == _Source.todo
                                              ? const Icon(
                                                  Icons.check_circle_outline,
                                                )
                                              : const Icon(Icons.event_note),
                                          title: Text(item.title),
                                          subtitle: Text(
                                            '$tag | ${item.subtitle}',
                                          ),
                                          trailing:
                                              item.source == _Source.todo &&
                                                  item.done
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Colors.green,
                                                )
                                              : null,
                                          onTap: () =>
                                              _showEventBottomSheet(item),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
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
