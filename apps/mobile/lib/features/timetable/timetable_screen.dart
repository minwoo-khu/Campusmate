import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const _prefKeyTimetablePath = 'timetable_image_path';

  bool _loaded = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadSavedPath();
  }

  String _t(String ko, String en) => context.tr(ko, en);

  Future<void> _loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
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

    final appDir = await getApplicationDocumentsDirectory();

    final ext = p.extension(pickedPath).toLowerCase();
    final safeExt = (ext == '.png' || ext == '.jpg' || ext == '.jpeg')
        ? ext
        : '.png';

    final targetPath = p.join(appDir.path, 'timetable$safeExt');
    await File(pickedPath).copy(targetPath);

    await _savePath(targetPath);
    setState(() => _imagePath = targetPath);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('시간표 이미지를 저장했습니다.', 'Timetable image saved.'))),
    );
  }

  Future<void> _removeImage() async {
    final path = _imagePath;
    if (path != null && !kIsWeb) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _savePath(null);
    setState(() => _imagePath = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('시간표 이미지를 삭제했습니다.', 'Timetable image removed.')),
      ),
    );
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
              itemBuilder: (_, __) {
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
                    '갤러리에서 이번 학기 시간표 이미지를 업로드하고\n확대/축소하여 확인하세요.',
                    'Upload your semester timetable image\nand zoom in/out to view.',
                  ),
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
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
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
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
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
                    onPressed: _removeImage,
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
