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

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _hasPdfSignature(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final header = await raf.read(5);
      return header.length == 5 &&
          header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46 &&
          header[4] == 0x2D;
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }

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
    int sourceBytes;
    try {
      sourceBytes = await sourceFile.length();
    } catch (_) {
      if (!context.mounted) return;
      _showError(
        context,
        context.tr(
          'PDF 파일을 읽을 수 없습니다. 다시 시도해주세요.',
          'Failed to read PDF file. Please try again.',
        ),
      );
      return;
    }
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
    final hasPdfSignature = await _hasPdfSignature(sourceFile);
    if (!hasPdfSignature) {
      if (!context.mounted) return;
      _showError(
        context,
        context.tr('올바른 PDF 파일이 아닙니다.', 'Invalid PDF file format.'),
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

    final fileName = _sanitizeUploadFileName(p.basename(pickedPath));
    String targetFile;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final safeCourseFolder = _safeFolderName(courseId);
      final folder = Directory(
        p.join(appDir.path, 'course_materials', safeCourseFolder),
      );
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final targetPath = p.join(folder.path, fileName);
      targetFile = await _uniquePath(targetPath);
      await sourceFile.copy(targetFile);
    } catch (_) {
      if (!context.mounted) return;
      _showError(
        context,
        context.tr('PDF 저장 중 오류가 발생했습니다.', 'Failed to save the PDF file.'),
      );
      return;
    }

    try {
      await box.add(
        CourseMaterial(
          courseId: courseId,
          fileName: p.basename(targetFile),
          localPath: targetFile,
          addedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      try {
        await File(targetFile).delete();
      } catch (_) {
        // ignore cleanup errors
      }
      if (!context.mounted) return;
      _showError(
        context,
        context.tr(
          'PDF 등록 중 오류가 발생했습니다.',
          'Failed to register the uploaded PDF.',
        ),
      );
      return;
    }

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

  static String _safeFolderName(String raw) {
    final out = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (out.isEmpty || out == '.' || out == '..') return 'course';
    const maxFolderChars = 80;
    if (out.length <= maxFolderChars) return out;
    return out.substring(0, maxFolderChars);
  }

  static String _sanitizeUploadFileName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001F]'), '_')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'document.pdf';
    }

    const maxChars = 120;
    if (cleaned.length <= maxChars) return cleaned;

    final ext = p.extension(cleaned);
    final base = p.basenameWithoutExtension(cleaned);
    final baseLimit = maxChars - ext.length;
    if (baseLimit <= 1 || base.isEmpty) {
      return cleaned.substring(0, maxChars);
    }
    final safeBase = base.length <= baseLimit
        ? base
        : base.substring(0, baseLimit);
    return '$safeBase$ext';
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
    try {
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
    } catch (_) {
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
                  try {
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
                  } catch (_) {
                    if (!context.mounted) return;
                    _showError(
                      context,
                      context.tr(
                        'PDF 복원 중 오류가 발생했습니다.',
                        'Failed to restore the deleted PDF.',
                      ),
                    );
                  }
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
