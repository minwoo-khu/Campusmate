import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('Settings')),
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
