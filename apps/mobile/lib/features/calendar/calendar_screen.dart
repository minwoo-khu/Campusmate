import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/ics_settings_screen.dart';
import '../todo/todo_add_screen.dart';
import '../todo/todo_edit_screen.dart';
import '../todo/todo_model.dart';
import 'ics_parser.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _prefKeyIcsUrl = 'ics_feed_url';

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  // ICS state
  bool _loading = false;
  String? _message;
  DateTime? _lastIcsSyncAt;
  List<IcsEvent> _icsEvents = [];

  @override
  void initState() {
    super.initState();
    _loadIcs();
  }

  String _fmtHm(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fmtSyncLabel(DateTime dt) {
    final ymd = dt.toLocal().toString().split(' ')[0];
    return '$ymd ${_fmtHm(dt.toLocal())}';
  }

  Future<void> _openIcsSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const IcsSettingsScreen()),
    );
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

  bool _sameYmd(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

  Widget _buildTodayPanel(Box<TodoItem> box) {
    final now = DateTime.now();
    final today = _ymd(now);
    final tomorrow = today.add(const Duration(days: 1));

    // --- ICS events today ---
    final icsToday = _icsEvents
        .where((e) => _sameYmd(e.start, today))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // --- Todos due today/tomorrow (incomplete first) ---
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
    final todayStr = today.toLocal().toString().split(' ')[0];

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
                Text(todayStr, style: const TextStyle(color: Colors.black54)),
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

            // --- Todo section ---
            Row(
              children: [
                const Icon(Icons.checklist, size: 18),
                const SizedBox(width: 6),
                const Text('Todo', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${dueSoon.length}',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 6),
            if (todoTop.isEmpty)
              const Text('No due soon', style: TextStyle(color: Colors.black54))
            else
              ...todoTop.map((t) {
                final due = t.dueAt!;
                final isTmr = _sameYmd(due, tomorrow);
                final when = isTmr ? 'Tomorrow' : 'Today';
                final time = _fmtHm(due);

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    t.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: t.completed ? Colors.green : null,
                  ),
                  title: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('$when • $time'),
                  onTap: () async {
                    setState(() {
                      _selectedDay = _ymd(due);
                      _focusedDay = _ymd(due);
                    });
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TodoEditScreen(item: t)),
                    );
                  },
                );
              }),

            const SizedBox(height: 8),

            // --- School section ---
            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 6),
                const Text('School', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${icsToday.length}',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 6),
            if (icsTop.isEmpty)
              const Text('No school events today',
                  style: TextStyle(color: Colors.black54))
            else
              ...icsTop.map((e) {
                final when = e.allDay ? 'All day' : _fmtHm(e.start);
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
                  onTap: () {
                    setState(() {
                      _selectedDay = today;
                      _focusedDay = today;
                    });
                  },
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
              // Header
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          color: _message!.startsWith('Failed') ? Colors.red : null,
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

                      // Todo items
                      for (final t in box.values) {
                        final due = t.dueAt;
                        if (due != null && _sameYmd(due, day)) {
                          items.add(
                            _CalItem(
                              title: t.title,
                              when: due,
                              source: _Source.todo,
                              subtitle: 'Due',
                              done: t.completed,
                            ),
                          );
                        }
                      }

                      // ICS events (start day only for MVP)
                      for (final e in _icsEvents) {
                        if (_sameYmd(e.start, day)) {
                          items.add(
                            _CalItem(
                              title: e.summary,
                              when: e.start,
                              source: _Source.ics,
                              subtitle: e.allDay ? 'All day' : 'School',
                              done: false,
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
                              eventLoader: itemsForDay, // dots/markers
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
                            'Selected: ${_selectedDay.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 6),

                        Expanded(
                          child: selectedItems.isEmpty
                              ? const Center(child: Text('No events on this day'))
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 120),
                                  itemCount: selectedItems.length,
                                  itemBuilder: (_, i) {
                                    final it = selectedItems[i];
                                    final tag =
                                        it.source == _Source.todo ? 'TODO' : 'SCHOOL';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Card(
                                        child: ListTile(
                                          leading: it.source == _Source.todo
                                              ? const Icon(Icons.check_circle_outline)
                                              : const Icon(Icons.event_note),
                                          title: Text(it.title),
                                          subtitle: Text('$tag • ${it.subtitle}'),
                                          trailing: it.source == _Source.todo && it.done
                                              ? const Icon(Icons.check, color: Colors.green)
                                              : null,
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

  _CalItem({
    required this.title,
    required this.when,
    required this.source,
    required this.subtitle,
    required this.done,
  });
}
