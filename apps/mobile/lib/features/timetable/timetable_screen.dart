import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/change_history_service.dart';
import '../../app/l10n.dart';
import '../../app/safety_limits.dart';
import '../../app/theme.dart';
import '../courses/course.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const _prefKeyTimetablePath = 'timetable_image_path';
  static const _maxAutoCandidates = 24;

  bool _loaded = false;
  bool _recognizingCourses = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadSavedPath();
  }

  String _t(String ko, String en) => context.tr(ko, en);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _imagePath = prefs.getString(_prefKeyTimetablePath);
      _loaded = true;
    });
  }

  Future<void> _savePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_prefKeyTimetablePath);
    } else {
      await prefs.setString(_prefKeyTimetablePath, path);
    }
  }

  String _courseKey(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();

  String _cleanCandidate(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    value = value.replaceAll(
      RegExp(r'\b\d{1,2}[:.]\d{2}\s*[-~]\s*\d{1,2}[:.]\d{2}\b'),
      ' ',
    );
    value = value.replaceAll(RegExp(r'\b\d{1,2}\s*교시\b'), ' ');
    value = value.replaceAll(
      RegExp(
        r'\(([^)]*(교수|강의실|분반|room|professor)[^)]*)\)',
        caseSensitive: false,
      ),
      ' ',
    );
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.length > SafetyLimits.maxCourseNameChars) {
      value = value.substring(0, SafetyLimits.maxCourseNameChars).trim();
    }
    return value;
  }

  bool _isLikelyNoise(String value) {
    if (!RegExp(r'[A-Za-z가-힣]').hasMatch(value)) return true;

    final compact = _courseKey(value);
    if (compact.isEmpty || compact.length < 2) return true;

    const blocked = <String>{
      '시간표',
      'timetable',
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
      '일',
      '월요일',
      '화요일',
      '수요일',
      '목요일',
      '금요일',
      '토요일',
      '일요일',
      'mon',
      'tue',
      'wed',
      'thu',
      'fri',
      'sat',
      'sun',
      'am',
      'pm',
      'online',
      'zoom',
      'room',
      '강의실',
      '과목명',
      '교수',
      '교시',
      '학기',
      '수강',
    };
    if (blocked.contains(compact)) return true;

    if (RegExp(r'^[0-9:~./-]+$').hasMatch(compact)) return true;
    if (RegExp(r'^\d{1,2}(교시)?$').hasMatch(compact)) return true;
    if (RegExp(r'^\d{1,2}[:.]\d{2}$').hasMatch(compact)) return true;

    return false;
  }

  List<String> _extractCourseCandidates(List<String> rawLines) {
    final byKey = <String, String>{};

    for (final line in rawLines) {
      final chunks = line
          .split(RegExp(r'[/|,;·•]+'))
          .map((e) => _cleanCandidate(e))
          .where((e) => e.isNotEmpty);

      for (final candidate in chunks) {
        if (_isLikelyNoise(candidate)) continue;
        final key = _courseKey(candidate);
        if (key.isEmpty || byKey.containsKey(key)) continue;
        byKey[key] = candidate;
        if (byKey.length >= _maxAutoCandidates) {
          return byKey.values.toList();
        }
      }
    }

    return byKey.values.toList();
  }

  Future<List<String>> _readCourseCandidatesFromImage(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(input);
      final lines = <String>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
        }
      }
      return _extractCourseCandidates(lines);
    } finally {
      await textRecognizer.close();
    }
  }

  Future<List<String>?> _showCourseImportSheet(List<String> candidates) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final cm = sheetContext.cmColors;
        final selected = List<bool>.filled(candidates.length, true);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedCount = selected.where((v) => v).length;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('시간표에서 인식한 강의', 'Detected courses from timetable'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cm.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _t(
                          '추가할 강의를 선택하세요. 필요 없는 항목은 체크 해제하면 됩니다.',
                          'Choose courses to add. Uncheck anything you do not need.',
                        ),
                        style: TextStyle(color: cm.textHint, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: candidates.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: cm.cardBorder),
                          itemBuilder: (_, i) {
                            return CheckboxListTile(
                              value: selected[i],
                              onChanged: (value) {
                                setSheetState(
                                  () => selected[i] = value ?? false,
                                );
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                candidates[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cm.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                for (var i = 0; i < selected.length; i++) {
                                  selected[i] = true;
                                }
                              });
                            },
                            child: Text(_t('전체 선택', 'Select all')),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                for (var i = 0; i < selected.length; i++) {
                                  selected[i] = false;
                                }
                              });
                            },
                            child: Text(_t('전체 해제', 'Clear all')),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: selectedCount == 0
                                ? null
                                : () {
                                    final picked = <String>[];
                                    for (
                                      var i = 0;
                                      i < candidates.length;
                                      i++
                                    ) {
                                      if (selected[i]) {
                                        picked.add(candidates[i]);
                                      }
                                    }
                                    Navigator.of(sheetContext).pop(picked);
                                  },
                            child: Text(
                              _t('$selectedCount개 추가', 'Add $selectedCount'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _recognizeAndImportCourses(String imagePath) async {
    if (_recognizingCourses || kIsWeb) return;

    final courseBox = Hive.box<Course>('courses');
    if (courseBox.length >= SafetyLimits.maxCourses) {
      _showError(
        _t(
          '강의 한도(${SafetyLimits.maxCourses}개)에 도달해 자동 등록을 건너뜁니다.',
          'Course limit reached (${SafetyLimits.maxCourses}). Skipping auto import.',
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _recognizingCourses = true);

    try {
      final candidates = await _readCourseCandidatesFromImage(imagePath);
      if (!mounted) return;

      if (candidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '강의명을 자동으로 찾지 못했어요. 필요하면 강의 탭에서 직접 추가해 주세요.',
                'No course names detected. Please add manually if needed.',
              ),
            ),
          ),
        );
        return;
      }

      final existingKeys = courseBox.values
          .map((c) => _courseKey(c.name))
          .toSet();
      final newCandidates = candidates
          .where((name) => !existingKeys.contains(_courseKey(name)))
          .toList();

      if (newCandidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '이미 등록된 강의만 인식되었어요.',
                'Detected courses are already registered.',
              ),
            ),
          ),
        );
        return;
      }

      final selected = await _showCourseImportSheet(newCandidates);
      if (!mounted || selected == null || selected.isEmpty) return;

      final remaining = SafetyLimits.maxCourses - courseBox.length;
      if (remaining <= 0) {
        _showError(
          _t(
            '강의 한도(${SafetyLimits.maxCourses}개)에 도달했습니다.',
            'Course limit reached (${SafetyLimits.maxCourses}).',
          ),
        );
        return;
      }

      final toAdd = selected.take(remaining).toList();
      for (var i = 0; i < toAdd.length; i++) {
        await courseBox.add(
          Course(
            id: '${DateTime.now().microsecondsSinceEpoch}_$i',
            name: toAdd[i],
          ),
        );
      }

      if (toAdd.isNotEmpty) {
        final preview = toAdd.take(5).join(', ');
        final detail = toAdd.length > 5
            ? '$preview 외 ${toAdd.length - 5}개'
            : preview;
        await ChangeHistoryService.log(
          'Courses imported from timetable',
          detail: detail,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '시간표에서 강의 ${toAdd.length}개를 추가했어요.',
                'Added ${toAdd.length} courses from timetable.',
              ),
            ),
          ),
        );
      }

      if (selected.length > toAdd.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                '강의 한도(${SafetyLimits.maxCourses}개)로 일부만 추가했어요.',
                'Only some courses were added due to course limit.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      _showError(
        _t(
          '시간표 이미지에서 강의 인식에 실패했습니다. 다시 시도해 주세요.',
          'Failed to detect courses from timetable image. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _recognizingCourses = false);
      }
    }
  }

  Future<void> _pickAndSaveImage() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '웹에서는 파일 저장 경로가 제한됩니다. 모바일에서 사용해 주세요.',
              'File save path is limited on web. Please use mobile.',
            ),
          ),
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedPath = result.files.single.path;
    if (pickedPath == null) return;

    final sourceFile = File(pickedPath);
    int sourceBytes;
    try {
      sourceBytes = await sourceFile.length();
    } catch (_) {
      _showError(
        _t(
          '이미지 파일을 읽을 수 없습니다. 다시 시도해주세요.',
          'Failed to read the image file. Please try again.',
        ),
      );
      return;
    }

    if (sourceBytes > SafetyLimits.maxTimetableImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '시간표 이미지 크기 한도(${(SafetyLimits.maxTimetableImageBytes / (1024 * 1024)).toStringAsFixed(0)}MB)를 초과했습니다.',
              'Timetable image is too large (limit ${(SafetyLimits.maxTimetableImageBytes / (1024 * 1024)).toStringAsFixed(0)}MB).',
            ),
          ),
        ),
      );
      return;
    }

    final ext = p.extension(pickedPath).toLowerCase();
    final safeExt = (ext == '.png' || ext == '.jpg' || ext == '.jpeg')
        ? ext
        : '.png';

    String targetPath;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      targetPath = p.join(appDir.path, 'timetable$safeExt');
      await sourceFile.copy(targetPath);
      await _savePath(targetPath);
    } catch (_) {
      _showError(_t('시간표 이미지 저장에 실패했습니다.', 'Failed to save timetable image.'));
      return;
    }

    if (!mounted) return;
    setState(() => _imagePath = targetPath);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('시간표 이미지를 저장했습니다.', 'Timetable image saved.'))),
    );

    unawaited(_recognizeAndImportCourses(targetPath));
  }

  Future<void> _removeImage() async {
    try {
      final path = _imagePath;
      if (path != null && !kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await _savePath(null);
    } catch (_) {
      _showError(
        _t('시간표 이미지 삭제에 실패했습니다.', 'Failed to remove timetable image.'),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _imagePath = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('시간표 이미지를 삭제했습니다.', 'Timetable image removed.')),
      ),
    );
  }

  Future<void> _confirmRemoveImage() async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_t('시간표 이미지 삭제', 'Delete timetable image')),
            content: Text(
              _t(
                '시간표 이미지를 삭제할까요?\n삭제하면 다시 업로드해야 합니다.',
                'Delete the timetable image?\nYou will need to upload it again.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_t('취소', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_t('삭제', 'Delete')),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await _removeImage();
  }

  Widget _buildPlaceholder() {
    final cm = context.cmColors;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 60,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
              ),
              itemBuilder: (_, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: cm.gridBorder, width: 0.6),
                  ),
                );
              },
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_outlined, size: 56, color: cm.checkInactive),
                const SizedBox(height: 14),
                Text(
                  _t('시간표 이미지가 없습니다', 'No timetable image'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cm.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    '갤러리에서 이번 학기 시간표 이미지를 선택해\n확대/축소해서 확인해 보세요.',
                    'Pick your semester timetable image\nand zoom in/out to review.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cm.textHint, height: 1.4),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _recognizingCourses ? null : _pickAndSaveImage,
                  style: FilledButton.styleFrom(
                    backgroundColor: cm.navActive,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_t('이미지 업로드 (로컬 저장)', 'Upload image (local)')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cm = context.cmColors;
    final hasImage = _imagePath != null && !kIsWeb;

    return Scaffold(
      backgroundColor: cm.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    _t('시간표', 'Timetable'),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: cm.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _recognizingCourses ? null : _pickAndSaveImage,
                    icon: const Icon(Icons.image_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: cm.iconButtonBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_recognizingCourses) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _t(
                      '시간표에서 강의명을 인식하는 중...',
                      'Detecting course names from timetable...',
                    ),
                    style: TextStyle(fontSize: 12, color: cm.textHint),
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 2),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cm.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cm.cardBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage
                      ? InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4,
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          ),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _recognizingCourses ? null : _confirmRemoveImage,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(_t('이미지 삭제', 'Delete image')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
