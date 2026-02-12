import 'package:flutter/material.dart';

import 'l10n.dart';
import '../main.dart';

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
    final appState = CampusMateApp.of(context);
    final currentMode = appState?.themeMode ?? ThemeMode.system;
    final currentLocaleCode = appState?.localeCode ?? 'ko';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('설정', 'Settings'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(context.tr('홈 화면', 'Home screen')),
            subtitle: Text(
              context.tr('시작 탭을 선택하세요', 'Choose which tab opens first'),
            ),
          ),
          RadioListTile<int>(
            value: 0,
            groupValue: _startTab,
            title: Text(context.tr('할 일', 'Todo')),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          RadioListTile<int>(
            value: 1,
            groupValue: _startTab,
            title: Text(context.tr('캘린더', 'Calendar')),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          RadioListTile<int>(
            value: 2,
            groupValue: _startTab,
            title: Text(context.tr('시간표', 'Timetable')),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          RadioListTile<int>(
            value: 3,
            groupValue: _startTab,
            title: Text(context.tr('강의', 'Courses')),
            onChanged: (v) => setState(() => _startTab = v!),
          ),
          const Divider(height: 32),
          ListTile(
            title: Text(context.tr('화면 테마', 'Appearance')),
            subtitle: Text(context.tr('테마 모드를 선택하세요', 'Choose theme mode')),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: currentMode,
            title: Text(context.tr('시스템', 'System')),
            subtitle: Text(context.tr('기기 설정 따르기', 'Follow device setting')),
            onChanged: (v) {
              appState?.setThemeMode(v!);
              setState(() {});
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: currentMode,
            title: Text(context.tr('라이트', 'Light')),
            onChanged: (v) {
              appState?.setThemeMode(v!);
              setState(() {});
            },
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: currentMode,
            title: Text(context.tr('다크', 'Dark')),
            onChanged: (v) {
              appState?.setThemeMode(v!);
              setState(() {});
            },
          ),
          const Divider(height: 32),
          ListTile(
            title: Text(context.tr('언어', 'Language')),
            subtitle: Text(context.tr('앱 언어를 선택하세요', 'Choose app language')),
          ),
          RadioListTile<String>(
            value: 'ko',
            groupValue: currentLocaleCode,
            title: const Text('한국어'),
            onChanged: (v) {
              if (v == null) return;
              appState?.setLocaleCode(v);
              setState(() {});
            },
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: currentLocaleCode,
            title: const Text('English'),
            onChanged: (v) {
              if (v == null) return;
              appState?.setLocaleCode(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_startTab),
              child: Text(context.tr('저장', 'Save')),
            ),
          ),
        ],
      ),
    );
  }
}
