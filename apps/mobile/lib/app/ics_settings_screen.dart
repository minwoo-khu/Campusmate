import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IcsSettingsScreen extends StatefulWidget {
  const IcsSettingsScreen({super.key});

  @override
  State<IcsSettingsScreen> createState() => _IcsSettingsScreenState();
}

class _IcsSettingsScreenState extends State<IcsSettingsScreen> {
  static const _prefKeyIcsUrl = 'ics_feed_url';

  final _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _controller.text = prefs.getString(_prefKeyIcsUrl) ?? '';
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    final prefs = await SharedPreferences.getInstance();
    if (url.isEmpty) {
      await prefs.remove(_prefKeyIcsUrl);
    } else {
      await prefs.setString(_prefKeyIcsUrl, url);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('School Calendar (ICS)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Paste your school iCal/ICS feed URL. Events will appear in Calendar as read-only.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'ICS feed URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
