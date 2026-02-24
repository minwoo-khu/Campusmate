import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/center_notice.dart';
import '../../app/l10n.dart';
import '../../app/safety_limits.dart';
import '../../app/theme.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const _prefKeyTimetablePath = 'timetable_image_path';
  static const _managedTimetableDirName = 'timetable';

  String? _imagePath;

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

  Future<void> _pickAndSaveImage() async {
    if (kIsWeb) {
      if (!mounted) return;
      CenterNotice.show(
        context,
        message: _t(
          '웹에서는 시간표 이미지를 저장할 수 없습니다. 모바일 앱을 사용해 주세요.',
          'Timetable image storage is not supported on web. Please use the mobile app.',
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
          '시간표 이미지 크기 제한(${(SafetyLimits.maxTimetableImageBytes / (1024 * 1024)).toStringAsFixed(0)}MB)을 초과했습니다.',
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
  }

  Future<void> _clearImage() async {
    final imagePath = _imagePath;
    if (!mounted) return;
    setState(() => _imagePath = null);
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
                '갤러리에서 이번 학기 시간표 이미지를 선택하고 확대/축소로 확인해 보세요.',
                'Pick your semester timetable image and zoom in/out to review.',
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(color: cm.textHint, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _pickAndSaveImage,
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
                    onPressed: _pickAndSaveImage,
                    icon: const Icon(Icons.image_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: cm.iconButtonBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                    onPressed: _clearImage,
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
