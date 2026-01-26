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
      // 웹은 로컬 파일 경로 저장 방식이 다름(IndexedDB/bytes 등)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('웹에서는 시간표 이미지 저장 기능을 잠시 비활성화했어. Windows/Android로 실행해줘.')),
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

    // 앱 전용 폴더로 복사해서 “항상 접근 가능한 경로”로 보관
    final appDir = await getApplicationDocumentsDirectory();
    final ext = p.extension(pickedPath).toLowerCase();
    final safeExt = (ext == '.png' || ext == '.jpg' || ext == '.jpeg') ? ext : '.png';
    final targetPath = p.join(appDir.path, 'timetable$safeExt');

    final src = File(pickedPath);
    await src.copy(targetPath);

    await _savePath(targetPath);
    setState(() => _imagePath = targetPath);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('시간표 이미지 저장 완료')),
    );
  }

  Future<void> _removeImage() async {
    if (_imagePath != null && !kIsWeb) {
      final f = File(_imagePath!);
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

    final hasImage = _imagePath != null && (!kIsWeb);

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
            Card(
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
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
            const SizedBox(height: 8),
            if (kIsWeb)
              const Text(
                '※ 웹(Chrome)에서는 저장 방식이 달라서 이 기능을 잠시 꺼뒀어. Windows/Android로 실행해줘.',
              ),
          ],
        ),
      ),
    );
  }
}
