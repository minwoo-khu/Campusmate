import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/ics_settings_screen.dart';
import '../todo/todo_model.dart';
import 'ics_parser.dart';
import '../todo/todo_add_screen.dart';


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
  List<IcsEvent> _icsEvents = [];

  @override
  void initState() {
    super.initState();
    _loadIcs();
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
      body: Padding(
        padding: const EdgeInsets.all(12),
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
                IconButton(
                  onPressed: _openIcsSettings,
                  icon: const Icon(Icons.link),
                  tooltip: 'School calendar (ICS)',
                ),
                IconButton(
                  onPressed: _loadIcs,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),

            if (_loading) const LinearProgressIndicator(),

            if (_message != null) ...[
              const SizedBox(height: 6),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.startsWith('Failed') ? Colors.red : null,
                ),
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
                      TableCalendar<_CalItem>(
                        firstDay: DateTime.utc(2000, 1, 1),
                        lastDay: DateTime.utc(2100, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _format,
                        selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
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

                      const SizedBox(height: 8),
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
                            : ListView.separated(
                                itemCount: selectedItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final it = selectedItems[i];
                                  final tag =
                                      it.source == _Source.todo ? 'TODO' : 'SCHOOL';

                                  return ListTile(
                                    leading: it.source == _Source.todo
                                        ? const Icon(Icons.check_circle_outline)
                                        : const Icon(Icons.event_note),
                                    title: Text(it.title),
                                    subtitle: Text('$tag • ${it.subtitle}'),
                                    trailing: it.source == _Source.todo && it.done
                                        ? const Icon(Icons.check, color: Colors.green)
                                        : null,
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
