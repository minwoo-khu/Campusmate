import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CampusMateApp());
}

class CampusMateApp extends StatelessWidget {
  const CampusMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusMate',
      theme: ThemeData(useMaterial3: true),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _prefKeyStartTab = 'start_tab_index';
  int _currentIndex = 0;
  bool _loaded = false;

  final _tabs = const [
    TodoScreen(),
    CalendarScreen(),
    TimetableScreen(),
    CourseScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadStartTab();
  }

  Future<void> _loadStartTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefKeyStartTab) ?? 0;
    setState(() {
      _currentIndex = saved.clamp(0, _tabs.length - 1);
      _loaded = true;
    });
  }

  Future<void> _setStartTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyStartTab, index);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final selected = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    currentStartTab: _currentIndex,
                  ),
                ),
              );

              if (selected != null) {
                // 시작 탭 저장(앱 재시작 시 적용). 지금 탭도 같이 바꿔주면 UX 좋음.
                await _setStartTab(selected);
                setState(() => _currentIndex = selected);
              }
            },
          )
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle), label: 'Todo'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.table_chart), label: 'Timetable'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final int currentStartTab;
  const SettingsScreen({super.key, required this.currentStartTab});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _startTab;

  @override
  void initState() {
    super.initState();
    _startTab = widget.currentStartTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Home screen'),
            subtitle: Text('Choose which tab opens first'),
          ),
          RadioListTile<int>(
            value: 0,
            groupValue: _startTab,
            title: const Text('Todo'),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          RadioListTile<int>(
            value: 1,
            groupValue: _startTab,
            title: const Text('Calendar'),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          RadioListTile<int>(
            value: 2,
            groupValue: _startTab,
            title: const Text('Timetable'),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          RadioListTile<int>(
            value: 3,
            groupValue: _startTab,
            title: const Text('Courses'),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_startTab),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 탭 화면(1차는 껍데기) ----

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Todo (MVP 1차)'));
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Calendar + ICS (MVP 1차)'));
  }
}

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Timetable (image view first)'));
  }
}

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Courses',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _CourseCard(
            title: '운영체제',
            subtitle: '요약/퀴즈 기능은 2차에 추가',
          ),
          _CourseCard(
            title: '컴퓨터네트워크',
            subtitle: 'PDF 업로드 → 요약/퀴즈 (준비중)',
          ),
          const SizedBox(height: 16),
          const Text('※ 지금은 UI 껍데기만 먼저 잡는 단계'),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _CourseCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.menu_book),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2차에서 기능 연결 예정')),
          );
        },
      ),
    );
  }
}
