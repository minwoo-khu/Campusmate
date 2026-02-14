import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/center_notice.dart';
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
  static const _managedTimetableDirName = 'timetable';
  static const _maxAutoCandidates = 24;

  bool _recognizingCourses = false;
  String? _imagePath;
  int _recognitionEpoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSavedTimetableImage());
  }

  String _t(String ko, String en) => context.tr(ko, en);

  void _showError(String message) {
    if (!mounted) return;
    CenterNotice.show(context, message: message, error: true);
  }

  Future<void> _restoreSavedTimetableImage() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_prefKeyTimetablePath);
    if (savedPath == null || savedPath.isEmpty) return;

    final file = File(savedPath);
    if (!await file.exists()) {
      await prefs.remove(_prefKeyTimetablePath);
      return;
    }

    var resolvedPath = savedPath;
    if (!await _isPathInsideAppDocuments(savedPath)) {
      resolvedPath = await _persistTimetableImage(file);
    }

    if (!mounted) return;
    setState(() => _imagePath = resolvedPath);
  }

  Future<bool> _isPathInsideAppDocuments(String path) async {
    final appDir = await getApplicationDocumentsDirectory();
    final root = p.normalize(appDir.path);
    final normalized = p.normalize(path);
    return normalized == root || p.isWithin(root, normalized);
  }

  String _normalizeImageExtension(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
      case '.bmp':
        return ext;
      default:
        return '.jpg';
    }
  }

  Future<void> _cleanupManagedTimetableFiles({
    required Directory dir,
    required String keepPath,
  }) async {
    final keepNormalized = p.normalize(keepPath);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (p.normalize(entity.path) == keepNormalized) continue;
      try {
        await entity.delete();
      } catch (_) {
        // Ignore best-effort cleanup failures.
      }
    }
  }

  Future<String> _persistTimetableImage(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _managedTimetableDirName));
    await dir.create(recursive: true);

    final ext = _normalizeImageExtension(sourceFile.path);
    final targetPath = p.join(dir.path, 'current$ext');
    final sourcePath = p.normalize(sourceFile.path);
    final normalizedTarget = p.normalize(targetPath);

    if (sourcePath != normalizedTarget) {
      await sourceFile.copy(targetPath);
    }
    await _cleanupManagedTimetableFiles(dir: dir, keepPath: normalizedTarget);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTimetablePath, targetPath);
    return targetPath;
  }

  Future<void> _clearPersistedTimetablePath(String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyTimetablePath);

    if (imagePath == null || imagePath.isEmpty) return;
    if (!await _isPathInsideAppDocuments(imagePath)) return;

    final file = File(imagePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Ignore delete failures for best-effort cleanup.
      }
    }
  }

  String _courseKey(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();

  bool _containsLetterLike(String value) {
    for (final rune in value.runes) {
      final isAsciiLetter =
          (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
      final isHangulSyllable = rune >= 0xAC00 && rune <= 0xD7A3;
      final isHangulJamo = rune >= 0x3131 && rune <= 0x318E;
      if (isAsciiLetter || isHangulSyllable || isHangulJamo) {
        return true;
      }
    }
    return false;
  }

  bool _containsDigit(String value) {
    for (final rune in value.runes) {
      if (rune >= 0x30 && rune <= 0x39) return true;
    }
    return false;
  }

  String _cleanCandidate(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    value = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    value = value.replaceAll(
      RegExp(r'\b\d{1,2}[:.]\d{2}\s*[-~]\s*\d{1,2}[:.]\d{2}\b'),
      ' ',
    );
    value = value.replaceAll(RegExp(r'\b\d{1,2}\s*교시\b'), ' ');
    value = value.replaceAll(
      RegExp(r'\(([^)]*(교수|분반|room|professor)[^)]*)\)', caseSensitive: false),
      ' ',
    );
    value = value.replaceAll(RegExp(r'^[\-•·]+'), '');
    value = value.replaceAll(RegExp(r'[:\-•·]+$'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (value.length > SafetyLimits.maxCourseNameChars) {
      value = value.substring(0, SafetyLimits.maxCourseNameChars).trim();
    }
    return value;
  }

  bool _isLikelyNoise(String value) {
    if (!_containsLetterLike(value)) return true;

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
      '강의명',
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
    if (!_containsLetterLike(compact) && _containsDigit(compact)) return true;

    return false;
  }

  List<String> _extractCourseCandidates(List<String> rawLines) {
    final byKey = <String, String>{};

    for (final rawLine in rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final splitChunks = line
          .split(RegExp(r'[/|,;·•+]'))
          .expand((chunk) => chunk.split(RegExp(r'\s{2,}')))
          .map(_cleanCandidate)
          .where((value) => value.isNotEmpty);

      for (final candidate in splitChunks) {
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

  String _normalizeBlockText(TextBlock block) {
    final lines = block.lines
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';

    // Timetable cells often split one course into multiple lines.
    // Join contiguous lines first, then trim trailing room-like tokens.
    var merged = lines.join(' ');
    merged = merged.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (merged.isEmpty) return '';

    final parts = merged.split(' ');
    if (parts.length >= 2) {
      final tail = parts.last;
      final looksRoomLike =
          RegExp(r'^[A-Za-z가-힣]{1,4}\d{2,4}[A-Za-z]?$').hasMatch(tail) ||
          RegExp(r'^[A-Za-z]?\d{2,4}[A-Za-z]?$').hasMatch(tail);
      if (looksRoomLike) {
        merged = parts.sublist(0, parts.length - 1).join(' ').trim();
      }
    }
    return merged;
  }

  List<String> _collectOcrUnits(RecognizedText recognizedText) {
    final out = <String>[];
    for (final block in recognizedText.blocks) {
      final normalized = _normalizeBlockText(block);
      if (normalized.isNotEmpty) {
        out.add(normalized);
      }
    }

    if (out.isNotEmpty) return out;

    // Fallback for images where blocks are sparse.
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) out.add(text);
      }
    }
    return out;
  }

  Future<String> _buildOcrImagePath(String sourcePath) async {
    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourcePath;

      const maxEdge = 2200;
      if (decoded.width <= maxEdge && decoded.height <= maxEdge) {
        return sourcePath;
      }

      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxEdge : null,
        height: decoded.height > decoded.width ? maxEdge : null,
        interpolation: img.Interpolation.average,
      );

      final tempDir = await getTemporaryDirectory();
      final ocrPath = p.join(tempDir.path, 'timetable_ocr.jpg');
      await File(
        ocrPath,
      ).writeAsBytes(img.encodeJpg(resized, quality: 88), flush: true);
      return ocrPath;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<List<String>> _readCourseCandidatesFromImage(String imagePath) async {
    final optimizedPath = await _buildOcrImagePath(imagePath);
    final input = InputImage.fromFilePath(optimizedPath);
    final byKey = <String, String>{};
    const scripts = <TextRecognitionScript>[
      TextRecognitionScript.korean,
      TextRecognitionScript.latin,
    ];

    for (final script in scripts) {
      final textRecognizer = TextRecognizer(script: script);
      try {
        final recognizedText = await textRecognizer.processImage(input);
        final candidates = _extractCourseCandidates(
          _collectOcrUnits(recognizedText),
        );
        for (final candidate in candidates) {
          final key = _courseKey(candidate);
          if (key.isEmpty || byKey.containsKey(key)) continue;
          byKey[key] = candidate;
          if (byKey.length >= _maxAutoCandidates) {
            return byKey.values.toList();
          }
        }
      } catch (_) {
        // Continue with the next script.
      } finally {
        await textRecognizer.close();
      }
    }

    return byKey.values.toList();
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
                          '추가할 강의를 선택해 주세요. 필요 없는 항목은 체크 해제하면 됩니다.',
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
          '강의 수가 최대치(${SafetyLimits.maxCourses}개)에 도달해 자동 추가를 건너뜁니다.',
          'Course limit reached (${SafetyLimits.maxCourses}). Skipping auto import.',
        ),
      );
      return;
    }

    final runEpoch = ++_recognitionEpoch;
    if (!mounted) return;
    setState(() => _recognizingCourses = true);

    try {
      final candidates = await _readCourseCandidatesFromImage(
        imagePath,
      ).timeout(const Duration(seconds: 30));
      if (!mounted || runEpoch != _recognitionEpoch) return;

      if (candidates.isEmpty) {
        CenterNotice.show(
          context,
          message: _t(
            '강의명을 자동으로 찾지 못했어요. 필요하면 강의 탭에서 직접 추가해 주세요.',
            'No course names detected. Please add manually if needed.',
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
        CenterNotice.show(
          context,
          message: _t(
            '이미 등록된 강의만 인식됐어요.',
            'Detected courses are already registered.',
          ),
        );
        return;
      }

      final selected = await _showCourseImportSheet(newCandidates);
      if (!mounted || runEpoch != _recognitionEpoch) return;
      if (selected == null || selected.isEmpty) return;

      final remaining = SafetyLimits.maxCourses - courseBox.length;
      if (remaining <= 0) {
        _showError(
          _t(
            '강의 수가 최대치(${SafetyLimits.maxCourses}개)에 도달했습니다.',
            'Course limit reached (${SafetyLimits.maxCourses}).',
          ),
        );
        return;
      }

      final toAdd = selected.take(remaining).toList();
      final baseId = DateTime.now().microsecondsSinceEpoch;
      for (var i = 0; i < toAdd.length; i++) {
        await courseBox.add(Course(id: '${baseId}_$i', name: toAdd[i]));
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
        if (!mounted || runEpoch != _recognitionEpoch) return;
        CenterNotice.show(
          context,
          message: _t(
            '시간표에서 강의 ${toAdd.length}개를 추가했어요.',
            'Added ${toAdd.length} courses from timetable.',
          ),
        );
      }

      if (selected.length > toAdd.length && mounted) {
        CenterNotice.show(
          context,
          message: _t(
            '강의 수 제한(${SafetyLimits.maxCourses}개)으로 일부만 추가했어요.',
            'Only some courses were added due to course limit.',
          ),
        );
      }
    } on TimeoutException {
      _showError(
        _t(
          '시간표 인식 시간이 길어져 중단했어요. 더 선명한 이미지를 다시 시도해 주세요.',
          'Recognition timed out. Please retry with a clearer image.',
        ),
      );
    } catch (_) {
      _showError(
        _t(
          '시간표 이미지에서 강의 인식에 실패했습니다. 다시 시도해 주세요.',
          'Failed to detect courses from timetable image. Please try again.',
        ),
      );
    } finally {
      if (mounted && runEpoch == _recognitionEpoch) {
        setState(() => _recognizingCourses = false);
      }
    }
  }

  Future<void> _pickAndSaveImage() async {
    if (kIsWeb) {
      if (!mounted) return;
      CenterNotice.show(
        context,
        message: _t(
          '웹에서는 파일 저장 경로가 제한됩니다. 모바일에서 사용해 주세요.',
          'File save path is limited on web. Please use mobile.',
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
          '이미지 파일을 읽을 수 없습니다. 다시 시도해 주세요.',
          'Failed to read the image file. Please try again.',
        ),
      );
      return;
    }

    if (sourceBytes > SafetyLimits.maxTimetableImageBytes) {
      if (!mounted) return;
      CenterNotice.show(
        context,
        message: _t(
          '시간표 이미지 크기 한도(${(SafetyLimits.maxTimetableImageBytes / (1024 * 1024)).toStringAsFixed(0)}MB)를 초과했습니다.',
          'Timetable image is too large (limit ${(SafetyLimits.maxTimetableImageBytes / (1024 * 1024)).toStringAsFixed(0)}MB).',
        ),
        error: true,
      );
      return;
    }

    String storedPath;
    try {
      storedPath = await _persistTimetableImage(sourceFile);
    } catch (_) {
      _showError(
        _t(
          '이미지를 저장할 수 없습니다. 다시 시도해 주세요.',
          'Failed to save the image. Please try again.',
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _imagePath = storedPath);

    unawaited(
      Future<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted || _imagePath != storedPath) return;
        await _recognizeAndImportCourses(storedPath);
      }),
    );
  }

  Future<void> _clearImage() async {
    _recognitionEpoch++;
    final imagePath = _imagePath;

    if (!mounted) return;
    setState(() {
      _imagePath = null;
      _recognizingCourses = false;
    });
    await _clearPersistedTimetablePath(imagePath);
  }

  Widget _buildPlaceholder() {
    final cm = context.cmColors;

    return Center(
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
                '갤러리에서 이번 학기 시간표 이미지를 선택해 확대/축소해서 확인해 보세요.',
                'Pick your semester timetable image from gallery and zoom in/out to review.',
              ),
              maxLines: 2,
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
              child: Text(_t('이미지 업로드', 'Upload image')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final hasImage =
        _imagePath != null && !kIsWeb && File(_imagePath!).existsSync();

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
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
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
                    onPressed: _recognizingCourses ? null : _clearImage,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(_t('이미지 지우기', 'Clear image')),
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
