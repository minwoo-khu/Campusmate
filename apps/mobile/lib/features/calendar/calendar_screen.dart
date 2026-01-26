import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../todo/todo_repo.dart';
import '../../app/ics_settings_screen.dart';
import 'ics_parser.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _prefKeyIcsUrl = 'ics_feed_url';

  bool _loadingIcs = false;
  String? _icsError;
  List<IcsEvent> _icsEvents = [];

  @override
  void initState() {
    super.initState();
    _loadIcs();
  }

  Future<void> _loadIcs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefKeyIcsUrl);

    setState(() {
      _loadingIcs = true;
      _icsError = null;
    });

    if (url == null || url.trim().isEmpty) {
      setState(() {
        _loadingIcs = false;
        _icsEvents = [];
      });
      return;
    }

    try {
      final resp = await http.get(Uri.parse(url.trim()));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final events = parseIcs(resp.body);
      events.sort((a, b) => a.start.compareTo(b.start));

      setState(() {
        _icsEvents = events;
        _loadingIcs = false;
      });
    } catch (e) {
      setState(() {
        _icsEvents = [];
        _loadingIcs = false;
        _icsError = 'ICS load failed: $e';
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
    final todosWithDue = todoRepo
        .list()
        .where((t) => t.dueAt != null)
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    // 통합 리스트(간단하게: todo due + ics start 기준으로 합쳐서 보여주기)
    final items = <_CalItem>[];

    for (final t in todosWithDue) {
      items.add(_CalItem(
        title: t.title,
        when: t.dueAt!,
        source: _Source.todo,
        subtitle: 'Due',
        done: t.completed,
      ));
    }

    for (final e in _icsEvents) {
      items.add(_CalItem(
        title: e.summary,
        when: e.start,
        source: _Source.ics,
        subtitle: e.allDay ? 'All day' : 'ICS',
        done: false,
      ));
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
                  tooltip: 'ICS settings',
                ),
                IconButton(
                  onPressed: _loadIcs,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_loadingIcs)
              const LinearProgressIndicator(),

            if (_icsError != null) ...[
              const SizedBox(height: 8),
              Text(_icsError!, style: const TextStyle(color: Colors.red)),
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
                        final dateStr =
                            it.when.toLocal().toString().split(' ')[0];

                        final leading = it.source == _Source.todo
                            ? const Icon(Icons.check_circle_outline)
                            : const Icon(Icons.event_note);

                        final tag = it.source == _Source.todo ? 'TODO' : 'ICS';

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
