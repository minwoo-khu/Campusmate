import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/center_notice.dart';
import '../../app/change_history_service.dart';
import '../../app/l10n.dart';
import '../../app/safety_limits.dart';
import '../../app/theme.dart';
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
    CenterNotice.show(context, message: message, error: true);
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
    final pickedFile = result.files.single;
    int sourceBytes;
    try {
      sourceBytes = await sourceFile.length();
    } catch (_) {
      if (!context.mounted) return;
      _showError(
        context,
        context.tr(
          'PDF 파일을 읽지 못했습니다. 다시 시도해 주세요.',
          'Failed to read PDF file. Please try again.',
        ),
      );
      return;
    }
    if (sourceBytes > SafetyLimits.maxCoursePdfBytes) {
      if (!context.mounted) return;
      CenterNotice.show(
        context,
        message: context.tr(
          'PDF 파일 크기 한도(${(SafetyLimits.maxCoursePdfBytes / (1024 * 1024)).toStringAsFixed(0)}MB)를 초과했습니다.',
          'PDF is too large (limit ${(SafetyLimits.maxCoursePdfBytes / (1024 * 1024)).toStringAsFixed(0)}MB).',
        ),
        error: true,
      );
      return;
    }
    final hasPdfSignature = await _hasPdfSignature(sourceFile);
    if (!hasPdfSignature) {
      if (!context.mounted) return;
      _showError(
        context,
        context.tr('올바른 PDF 파일 형식이 아닙니다.', 'Invalid PDF file format.'),
      );
      return;
    }

    final box = Hive.box<CourseMaterial>('course_materials');
    final currentCount = box.values.where((m) => m.courseId == courseId).length;
    if (currentCount >= SafetyLimits.maxMaterialsPerCourse) {
      if (!context.mounted) return;
      CenterNotice.show(
        context,
        message: context.tr(
          '강의당 PDF 한도(${SafetyLimits.maxMaterialsPerCourse}개)에 도달했습니다.',
          'PDF limit reached for this course (${SafetyLimits.maxMaterialsPerCourse}).',
        ),
        error: true,
      );
      return;
    }

    final fileName = _sanitizeUploadFileName(
      _resolvePickedFileName(pickedFile.name, pickedPath),
    );
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
        context.tr('PDF 파일 저장에 실패했습니다.', 'Failed to save the PDF file.'),
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
          '업로드한 PDF 등록에 실패했습니다.',
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
    CenterNotice.show(
      context,
      message: context.tr('PDF를 업로드했습니다.', 'PDF uploaded.'),
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

  static String _resolvePickedFileName(String pickerName, String pickedPath) {
    var candidate = pickerName.trim();
    if (candidate.isEmpty) {
      candidate = p.basename(pickedPath);
    } else {
      candidate = p.basename(candidate);
    }

    if (candidate.contains('%')) {
      try {
        candidate = Uri.decodeComponent(candidate);
      } catch (_) {
        // keep the original candidate when decode fails
      }
    }

    return candidate;
  }

  Future<void> _deleteMaterial(
    BuildContext context,
    CourseMaterial material,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cm = dialogContext.cmColors;
        return AlertDialog(
          title: Text(dialogContext.tr('PDF를 삭제할까요?', 'Delete PDF?')),
          content: Text(material.fileName),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.tr('취소', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cm.deleteBg,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.tr('삭제', 'Delete')),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final fileName = material.fileName;
    final f = File(material.localPath);
    try {
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // Ignore local file cleanup failures.
    }

    await material.delete();
    await ChangeHistoryService.log('PDF deleted', detail: fileName);

    if (!context.mounted) return;
    CenterNotice.show(
      context,
      message: context.tr('"$fileName" PDF를 삭제했습니다.', 'Deleted "$fileName".'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cm = context.cmColors;
    final box = Hive.box<CourseMaterial>('course_materials');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          courseName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: cm.textPrimary,
          ),
        ),
      ),
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
                  '아직 PDF가 없습니다. + 버튼으로 업로드해 보세요.',
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
                subtitle: Text(context.tr('추가일: $dateStr', 'Added: $dateStr')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteMaterial(context, material),
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
