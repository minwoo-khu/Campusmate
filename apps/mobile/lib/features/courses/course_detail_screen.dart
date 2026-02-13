import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/change_history_service.dart';
import '../../app/l10n.dart';
import '../../app/safety_limits.dart';
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

    final sourceFile = File(pickedPath);
    final sourceBytes = await sourceFile.length();
    if (sourceBytes > SafetyLimits.maxCoursePdfBytes) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'PDF ?ш린 ?쒕룄(${(SafetyLimits.maxCoursePdfBytes / (1024 * 1024)).toStringAsFixed(0)}MB)瑜?珥덇낵?덉뒿?덈떎.',
              'PDF is too large (limit ${(SafetyLimits.maxCoursePdfBytes / (1024 * 1024)).toStringAsFixed(0)}MB).',
            ),
          ),
        ),
      );
      return;
    }

    final box = Hive.box<CourseMaterial>('course_materials');
    final currentCount = box.values.where((m) => m.courseId == courseId).length;
    if (currentCount >= SafetyLimits.maxMaterialsPerCourse) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '媛뺤쓽蹂?PDF ?쒕룄(${SafetyLimits.maxMaterialsPerCourse}媛????꾨떖?덉뒿?덈떎.',
              'PDF limit reached for this course (${SafetyLimits.maxMaterialsPerCourse}).',
            ),
          ),
        ),
      );
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(appDir.path, 'course_materials', courseId));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final fileName = p.basename(pickedPath);
    final targetPath = p.join(folder.path, fileName);
    final targetFile = await _uniquePath(targetPath);

    await sourceFile.copy(targetFile);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('PDF瑜??낅줈?쒗뻽?듬땲??', 'PDF uploaded.'))),
    );
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
        title: Text(context.tr('PDF瑜???젣?좉퉴??', 'Delete PDF?')),
        content: Text(material.fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('痍⑥냼', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('??젣', 'Delete')),
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
    var undoAvailable = true;
    final f = File(material.localPath);
    if (await f.exists()) {
      final fileBytes = await f.length();
      if (fileBytes <= SafetyLimits.maxUndoPdfBytes) {
        bytes = await f.readAsBytes();
      } else {
        undoAvailable = false;
      }
      await f.delete();
    } else {
      undoAvailable = false;
    }

    await material.delete();
    await ChangeHistoryService.log('PDF deleted', detail: backup.fileName);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          undoAvailable
              ? context.tr(
                  'Deleted "${backup.fileName}"',
                  'Deleted "${backup.fileName}"',
                )
              : context.tr(
                  'Deleted "${backup.fileName}" (undo disabled for large file)',
                  'Deleted "${backup.fileName}" (undo disabled for large file)',
                ),
        ),
        action: undoAvailable
            ? SnackBarAction(
                label: context.tr('Undo', 'Undo'),
                onPressed: () async {
                  if (bytes != null) {
                    final restoreFile = File(backup.localPath);
                    await restoreFile.parent.create(recursive: true);
                    await restoreFile.writeAsBytes(bytes);
                  }

                  await Hive.box<CourseMaterial>(
                    'course_materials',
                  ).add(backup);
                  await ChangeHistoryService.log(
                    'PDF restored',
                    detail: backup.fileName,
                  );
                },
              )
            : null,
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
            return Center(
              child: Text(
                context.tr(
                  '?꾩쭅 PDF媛 ?놁뒿?덈떎. + 踰꾪듉?쇰줈 ?낅줈?쒗븯?몄슂.',
                  'No PDFs yet. Tap + to upload.',
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: materials.length,
            separatorBuilder: (_, separatorIndex) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final material = materials[i];
              final dateStr = material.addedAt.toLocal().toString().split(
                ' ',
              )[0];

              return ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(material.fileName),
                subtitle: Text(context.tr('異붽??? $dateStr', 'Added: $dateStr')),
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
