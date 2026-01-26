import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/ics_settings_screen.dart';
import '../todo/todo_repo.dart';
import 'ics_parser.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _prefKeyIcsUrl = 'ics_feed_url';

  bool _loading = false;
  String? _message; // 상태/에러 메시지
  List<IcsEvent> _icsEvents = [];

  @override
  void initState() {
    super.initState();
    _loadIcs();
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

      final events = parseIcs(resp.body)..sort((a, b) => a.start.compareTo(b.start));

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

  Future<void> _openIcsSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const IcsSettingsScreen()),
    );
    if (changed == true) {
      await _loadIcs();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Todo due-date
    final todosWithDue = todoRepo
        .list()
        .where((t) => t.dueAt != null)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    // 통합 이벤트
    final items = <_CalItem>[];

    for (final t in todosWithDue) {
      items.add(
        _CalItem(
          title: t.title,
          when: t.dueAt!,
          source: _Source.todo,
          subtitle: 'Due',
          done: t.completed,
        ),
      );
    }

    for (final e in _icsEvents) {
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

    items.sort((a, b) => a.when.compareTo(b.when));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 8),

            if (_loading) const LinearProgressIndicator(),

            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.startsWith('Failed') ? Colors.red : null,
                ),
              ),
            ],

            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No events yet'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final dateStr = it.when.toLocal().toString().split(' ')[0];

                        final leading = it.source == _Source.todo
                            ? const Icon(Icons.check_circle_outline)
                            : const Icon(Icons.event_note);

                        final tag = it.source == _Source.todo ? 'TODO' : 'SCHOOL';

                        return ListTile(
                          leading: leading,
                          title: Text(it.title),
                          subtitle: Text('$tag • ${it.subtitle} • $dateStr'),
                          trailing: it.source == _Source.todo && it.done
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
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
