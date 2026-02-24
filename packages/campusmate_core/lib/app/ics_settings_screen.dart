import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'center_notice.dart';
import 'l10n.dart';

class IcsSettingsScreen extends StatefulWidget {
  const IcsSettingsScreen({super.key});

  @override
  State<IcsSettingsScreen> createState() => _IcsSettingsScreenState();
}

class _IcsSettingsScreenState extends State<IcsSettingsScreen> {
  static const _prefKeyIcsUrl = 'ics_feed_url';

  final _controller = TextEditingController();
  bool _loaded = false;

  String _t(String ko, String en) => context.tr(ko, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _controller.text = prefs.getString(_prefKeyIcsUrl) ?? '';
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    final prefs = await SharedPreferences.getInstance();
    if (url.isEmpty) {
      await prefs.remove(_prefKeyIcsUrl);
    } else {
      if (url.length > 2048) {
        if (!mounted) return;
        CenterNotice.show(
          context,
          message: _t('URL이 너무 깁니다.', 'URL is too long.'),
          error: true,
        );
        return;
      }
      final uri = Uri.tryParse(url);
      final isHttps =
          uri != null &&
          uri.scheme.toLowerCase() == 'https' &&
          uri.host.isNotEmpty;
      if (!isHttps) {
        if (!mounted) return;
        CenterNotice.show(
          context,
          message: _t(
            'HTTPS ICS URL만 사용할 수 있습니다.',
            'Only HTTPS ICS URLs are allowed.',
          ),
          error: true,
        );
        return;
      }
      final normalized = uri.replace(fragment: '').toString();
      await prefs.setString(_prefKeyIcsUrl, normalized);
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('학교 캘린더 (ICS)', 'School Calendar (ICS)')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              context.tr(
                '학교 iCal/ICS 피드 URL을 붙여 넣으세요. 일정은 캘린더에 읽기 전용으로 표시됩니다.',
                'Paste your school iCal/ICS feed URL. Events will appear in Calendar as read-only.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: context.tr('ICS 피드 URL', 'ICS feed URL'),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(context.tr('저장', 'Save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
