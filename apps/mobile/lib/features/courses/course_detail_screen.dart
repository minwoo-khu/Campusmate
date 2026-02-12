import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/change_history_service.dart';
import 'course_material.dart';
import 'pdf_viewer_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final String courseId;
  final String courseName;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  Future<void> _pickAndSavePdf(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedPath = result.files.single.path;
    if (pickedPath == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(appDir.path, 'course_materials', courseId));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final fileName = p.basename(pickedPath);
    final targetPath = p.join(folder.path, fileName);
    final targetFile = await _uniquePath(targetPath);

    await File(pickedPath).copy(targetFile);

    final box = Hive.box<CourseMaterial>('course_materials');
    await box.add(
      CourseMaterial(
        courseId: courseId,
        fileName: p.basename(targetFile),
        localPath: targetFile,
        addedAt: DateTime.now(),
      ),
    );

    await ChangeHistoryService.log(
      'PDF uploaded',
      detail: p.basename(targetFile),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PDF uploaded.')));
  }

  static Future<String> _uniquePath(String path) async {
    if (!await File(path).exists()) return path;

    final dir = p.dirname(path);
    final base = p.basenameWithoutExtension(path);
    final ext = p.extension(path);

    int i = 1;
    while (true) {
      final candidate = p.join(dir, '$base ($i)$ext');
      if (!await File(candidate).exists()) return candidate;
      i++;
    }
  }

  Future<void> _deleteMaterialWithUndo(
    BuildContext context,
    CourseMaterial material,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete PDF?'),
        content: Text(material.fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final backup = CourseMaterial(
      courseId: material.courseId,
      fileName: material.fileName,
      localPath: material.localPath,
      addedAt: material.addedAt,
    );

    List<int>? bytes;
    final f = File(material.localPath);
    if (await f.exists()) {
      bytes = await f.readAsBytes();
      await f.delete();
    }

    await material.delete();
    await ChangeHistoryService.log('PDF deleted', detail: backup.fileName);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${backup.fileName}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (bytes != null) {
              final restoreFile = File(backup.localPath);
              await restoreFile.parent.create(recursive: true);
              await restoreFile.writeAsBytes(bytes);
            }

            await Hive.box<CourseMaterial>('course_materials').add(backup);
            await ChangeHistoryService.log(
              'PDF restored',
              detail: backup.fileName,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<CourseMaterial>('course_materials');

    return Scaffold(
      appBar: AppBar(title: Text(courseName)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndSavePdf(context),
        child: const Icon(Icons.upload_file),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<CourseMaterial> b, _) {
          final materials =
              b.values.where((m) => m.courseId == courseId).toList()
                ..sort((a, c) => c.addedAt.compareTo(a.addedAt));

          if (materials.isEmpty) {
            return const Center(child: Text('No PDFs yet. Tap + to upload.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: materials.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final material = materials[i];
              final dateStr = material.addedAt.toLocal().toString().split(
                ' ',
              )[0];

              return ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(material.fileName),
                subtitle: Text('Added: $dateStr'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteMaterialWithUndo(context, material),
                ),
                onTap: () {
                  final k = material.key;
                  if (k is int) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          materialKey: k,
                          filePath: material.localPath,
                          fileName: material.fileName,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
