import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'data_backup_service.dart';
import 'l10n.dart';

class SettingsScreen extends StatefulWidget {
  final int currentStartTab;

  const SettingsScreen({super.key, required this.currentStartTab});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _startTab;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startTab = widget.currentStartTab;
  }

  String _t(String ko, String en) => context.tr(ko, en);

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return _t('시스템', 'System');
      case ThemeMode.light:
        return _t('라이트', 'Light');
      case ThemeMode.dark:
        return _t('다크', 'Dark');
    }
  }

  String _startTabLabel(int index) {
    switch (index) {
      case 0:
        return _t('할 일', 'Todo');
      case 1:
        return _t('캘린더', 'Calendar');
      case 2:
        return _t('시간표', 'Timetable');
      case 3:
        return _t('강의', 'Courses');
      default:
        return '$index';
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';
      String? targetPath;
      try {
        targetPath = await FilePicker.platform.saveFile(
          dialogTitle: _t('백업 저장 위치 선택', 'Choose backup destination'),
          fileName: 'campusmate_backup_$stamp.json',
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );
      } catch (_) {
        targetPath = null;
      }

      final result = await DataBackupService.exportToFile(
        targetPath: targetPath,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '백업 저장 완료 (${result.summary.todos}개 할 일, ${result.summary.courses}개 강의)',
              'Backup exported (${result.summary.todos} todos, ${result.summary.courses} courses)',
            ),
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('백업 실패: ${e.message}', 'Backup failed: ${e.message}'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('백업 중 오류가 발생했습니다.', 'Backup failed.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importBackup() async {
    final shouldRestore =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(_t('백업 복원', 'Restore backup')),
              content: Text(
                _t(
                  '현재 데이터가 백업 내용으로 덮어쓰기됩니다. 계속할까요?',
                  'Current data will be replaced by backup data. Continue?',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_t('취소', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_t('복원', 'Restore')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRestore) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;

    final path = picked.files.single.path;
    if (path == null || path.isEmpty) return;

    setState(() => _busy = true);
    try {
      final result = await DataBackupService.importFromFile(path);

      if (!mounted) return;
      final appState = CampusMateApp.of(context);
      await appState?.setThemeMode(_parseThemeMode(result.themeMode));
      await appState?.setLocaleCode(result.localeCode);

      if (!mounted) return;
      setState(() => _startTab = result.startTab);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '복원 완료 (${result.summary.todos}개 할 일, ${result.summary.courses}개 강의)',
              'Restore completed (${result.summary.todos} todos, ${result.summary.courses} courses)',
            ),
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('복원 실패: ${e.message}', 'Restore failed: ${e.message}'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('복원 중 오류가 발생했습니다.', 'Restore failed.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = CampusMateApp.of(context);
    final currentMode = appState?.themeMode ?? ThemeMode.system;
    final currentLocaleCode = appState?.localeCode ?? 'ko';

    return Scaffold(
      appBar: AppBar(title: Text(_t('설정', 'Settings'))),
      body: IgnorePointer(
        ignoring: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _SectionTitle(
              title: _t('홈 화면', 'Home screen'),
              subtitle: _t('시작 탭을 선택하세요', 'Choose which tab opens first'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(4, (index) {
                return ChoiceChip(
                  label: Text(_startTabLabel(index)),
                  selected: _startTab == index,
                  onSelected: (_) => setState(() => _startTab = index),
                );
              }),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: _t('화면 테마', 'Appearance'),
              subtitle: _t('테마 모드를 선택하세요', 'Choose theme mode'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ThemeMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(_themeModeLabel(mode)),
                  selected: currentMode == mode,
                  onSelected: (_) async {
                    await appState?.setThemeMode(mode);
                    if (mounted) setState(() {});
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: _t('언어', 'Language'),
              subtitle: _t('앱 언어를 선택하세요', 'Choose app language'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('한국어'),
                  selected: currentLocaleCode == 'ko',
                  onSelected: (_) async {
                    await appState?.setLocaleCode('ko');
                    if (mounted) setState(() {});
                  },
                ),
                ChoiceChip(
                  label: const Text('English'),
                  selected: currentLocaleCode == 'en',
                  onSelected: (_) async {
                    await appState?.setLocaleCode('en');
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: _t('데이터', 'Data'),
              subtitle: _t(
                '백업 파일로 내보내거나 복원할 수 있습니다',
                'Export or restore using a backup file',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(_t('백업 내보내기', 'Export backup')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _importBackup,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_t('백업 복원', 'Restore backup')),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_startTab),
              child: Text(_t('저장', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  String _two(int x) => x.toString().padLeft(2, '0');
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
