import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'data_backup_service.dart';
import 'l10n.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  final int currentStartTab;

  const SettingsScreen({super.key, required this.currentStartTab});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _startTab;
  bool _busy = false;
  bool _hasBackupPin = false;

  @override
  void initState() {
    super.initState();
    _startTab = widget.currentStartTab;
    _loadBackupPinState();
  }

  String _t(String ko, String en) => context.tr(ko, en);

  ButtonStyle _filledStyle(BuildContext context) {
    final cm = context.cmColors;
    return FilledButton.styleFrom(
      backgroundColor: cm.navActive,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context, {bool destructive = false}) {
    final cm = context.cmColors;
    final fg = destructive ? cm.deleteBg : cm.textSecondary;
    return OutlinedButton.styleFrom(
      foregroundColor: fg,
      side: BorderSide(color: destructive ? cm.deleteBg : cm.cardBorder),
      backgroundColor: cm.inputBg,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  ButtonStyle _textStyle(BuildContext context) {
    final cm = context.cmColors;
    return TextButton.styleFrom(
      foregroundColor: cm.textSecondary,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  Future<void> _loadBackupPinState() async {
    final hasPin = await DataBackupService.hasBackupPin();
    if (!mounted) return;
    setState(() => _hasBackupPin = hasPin);
  }

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
        return _t('홈', 'Home');
      case 1:
        return _t('할 일', 'Todo');
      case 2:
        return _t('캘린더', 'Calendar');
      case 3:
        return _t('시간표', 'Timetable');
      case 4:
        return _t('강의', 'Courses');
      default:
        return '$index';
    }
  }

  Future<String?> _promptPin({
    required String title,
    required String confirmLabel,
    String? message,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final cm = dialogContext.cmColors;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                Text(message),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 16,
                decoration: InputDecoration(
                  labelText: _t('PIN', 'PIN'),
                  hintText: _t('숫자 4자리 이상', 'At least 4 digits'),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: cm.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cm.navActive, width: 1.6),
                  ),
                  filled: true,
                  fillColor: cm.inputBg,
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: _textStyle(dialogContext),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('취소', 'Cancel')),
            ),
            FilledButton(
              style: _filledStyle(dialogContext),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _setOrChangeBackupPin() async {
    if (_hasBackupPin) {
      final currentPin = await _promptPin(
        title: _t('현재 백업 PIN 확인', 'Verify current backup PIN'),
        confirmLabel: _t('확인', 'Verify'),
      );
      if (currentPin == null) return;

      final ok = await DataBackupService.verifyBackupPin(currentPin);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('PIN이 올바르지 않습니다.', 'Incorrect PIN.'))),
        );
        return;
      }
    }

    final newPin = await _promptPin(
      title: _t('새 백업 PIN 설정', 'Set new backup PIN'),
      confirmLabel: _t('다음', 'Next'),
      message: _t(
        '백업 파일 암호화를 위해 사용할 PIN입니다.',
        'This PIN will encrypt backup files.',
      ),
    );
    if (newPin == null) return;

    final confirmPin = await _promptPin(
      title: _t('새 PIN 다시 입력', 'Confirm new PIN'),
      confirmLabel: _t('저장', 'Save'),
    );
    if (confirmPin == null) return;

    if (newPin != confirmPin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('PIN이 일치하지 않습니다.', 'PIN does not match.'))),
      );
      return;
    }

    try {
      await DataBackupService.setBackupPin(newPin);
      if (!mounted) return;
      setState(() => _hasBackupPin = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('백업 PIN이 설정되었습니다.', 'Backup PIN has been set.')),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('설정 실패: ${e.message}', 'Failed: ${e.message}')),
        ),
      );
    }
  }

  Future<void> _clearBackupPin() async {
    if (!_hasBackupPin) return;

    final pin = await _promptPin(
      title: _t('백업 PIN 해제', 'Disable backup PIN'),
      confirmLabel: _t('해제', 'Disable'),
      message: _t(
        '현재 PIN을 입력하면 백업 암호화가 해제됩니다.',
        'Enter current PIN to disable backup encryption.',
      ),
    );
    if (pin == null) return;

    final ok = await DataBackupService.verifyBackupPin(pin);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('PIN이 올바르지 않습니다.', 'Incorrect PIN.'))),
      );
      return;
    }

    await DataBackupService.clearBackupPin();
    if (!mounted) return;
    setState(() => _hasBackupPin = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('백업 PIN이 해제되었습니다.', 'Backup PIN has been disabled.')),
      ),
    );
  }

  Future<String?> _resolvePinForExport() async {
    if (!_hasBackupPin) return null;
    final pin = await _promptPin(
      title: _t('백업 내보내기 PIN', 'Export backup PIN'),
      confirmLabel: _t('내보내기', 'Export'),
      message: _t(
        '암호화 백업 생성을 위해 PIN을 입력하세요.',
        'Enter PIN to create encrypted backup.',
      ),
    );
    if (pin == null) return null;

    final ok = await DataBackupService.verifyBackupPin(pin);
    if (!ok) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('PIN이 올바르지 않습니다.', 'Incorrect PIN.'))),
      );
      return null;
    }

    return pin;
  }

  Future<void> _exportBackup() async {
    String? pin;
    if (_hasBackupPin) {
      pin = await _resolvePinForExport();
      if (pin == null) return;
    }

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
        pin: pin,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.encrypted
                ? _t(
                    '암호화 백업 완료 (${result.summary.todos}개 할 일)',
                    'Encrypted backup exported (${result.summary.todos} todos)',
                  )
                : _t(
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
            final cm = dialogContext.cmColors;
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
                  style: _textStyle(dialogContext),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_t('취소', 'Cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cm.deleteBg,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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

    String? importPin;
    final encrypted = await DataBackupService.isEncryptedBackupFile(path);
    if (encrypted) {
      importPin = await _promptPin(
        title: _t('암호화 백업 PIN', 'Encrypted backup PIN'),
        confirmLabel: _t('복원', 'Restore'),
        message: _t(
          '선택한 백업 파일의 PIN을 입력하세요.',
          'Enter PIN for selected backup file.',
        ),
      );
      if (importPin == null) return;
    }

    setState(() => _busy = true);
    try {
      final result = await DataBackupService.importFromFile(
        path,
        pin: importPin,
      );

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
            result.encrypted
                ? _t(
                    '암호화 백업 복원 완료 (${result.summary.todos}개 할 일)',
                    'Encrypted backup restored (${result.summary.todos} todos)',
                  )
                : _t(
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
    final cm = context.cmColors;

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
              children: List.generate(5, (index) {
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
                '백업 파일 내보내기/복원 및 PIN 암호화를 관리합니다',
                'Manage backup export/restore and PIN encryption',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: _outlinedStyle(context),
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(_t('백업 내보내기', 'Export backup')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: _filledStyle(context),
                    onPressed: _importBackup,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_t('백업 복원', 'Restore backup')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: cm.inputBg,
                border: Border.all(color: cm.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasBackupPin
                        ? _t('백업 PIN: 설정됨', 'Backup PIN: Enabled')
                        : _t('백업 PIN: 미설정', 'Backup PIN: Disabled'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: _outlinedStyle(context),
                          onPressed: _setOrChangeBackupPin,
                          child: Text(
                            _hasBackupPin
                                ? _t('PIN 변경', 'Change PIN')
                                : _t('PIN 설정', 'Set PIN'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: _outlinedStyle(context, destructive: true),
                          onPressed: _hasBackupPin ? _clearBackupPin : null,
                          child: Text(_t('PIN 해제', 'Disable PIN')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: _filledStyle(context),
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
    final cm = context.cmColors;
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
            ).textTheme.bodySmall?.copyWith(color: cm.textHint),
          ),
        ],
      ),
    );
  }
}
