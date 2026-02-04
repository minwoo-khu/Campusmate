import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  static const _prefKeyTimetablePath = 'timetable_image_path';

  bool _loaded = false;
  String? _imagePath; // 로컬 파일 경로

  @override
  void initState() {
    super.initState();
    _loadSavedPath();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('웹에서는 지원 안 함. Android에서 실행해줘.')),
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
    final safeExt = (ext == '.png' || ext == '.jpg' || ext == '.jpeg') ? ext : '.png';

    final targetPath = p.join(appDir.path, 'timetable$safeExt');
    await File(pickedPath).copy(targetPath);

    await _savePath(targetPath);
    setState(() => _imagePath = targetPath);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('시간표 이미지 저장 완료')),
    );
  }

  Future<void> _removeImage() async {
    final path = _imagePath;
    if (path != null && !kIsWeb) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
    await _savePath(null);
    setState(() => _imagePath = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('시간표 이미지 삭제 완료')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasImage = _imagePath != null && !kIsWeb;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timetable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.file(
                          File(_imagePath!),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return const Center(
                              child: Text('이미지를 불러올 수 없어. 다시 업로드해줘.'),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_outlined, size: 44),
                            SizedBox(height: 8),
                            Text('No timetable image yet'),
                            SizedBox(height: 4),
                            Text('Upload an image to display here'),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pickAndSaveImage,
                icon: const Icon(Icons.upload),
                label: const Text('Upload timetable image'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_imagePath == null) ? null : _removeImage,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove image'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
