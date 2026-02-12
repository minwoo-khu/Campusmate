import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/courses/course.dart';
import '../features/courses/course_material.dart';
import '../features/todo/todo_model.dart';
import '../features/todo/todo_repo.dart';
import 'change_history_service.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';

class BackupSummary {
  final int todos;
  final int courses;
  final int materials;

  const BackupSummary({
    required this.todos,
    required this.courses,
    required this.materials,
  });
}

class BackupExportResult {
  final String filePath;
  final BackupSummary summary;

  const BackupExportResult({required this.filePath, required this.summary});
}

class BackupImportResult {
  final BackupSummary summary;
  final int startTab;
  final String themeMode;
  final String localeCode;

  const BackupImportResult({
    required this.summary,
    required this.startTab,
    required this.themeMode,
    required this.localeCode,
  });
}

class DataBackupService {
  DataBackupService._();

  static const _schemaVersion = 1;

  static const _prefStartTab = 'start_tab_index';
  static const _prefThemeMode = 'theme_mode';
  static const _prefLocaleCode = 'locale_code';
  static const _prefIcsUrl = 'ics_feed_url';
  static const _prefIcsCacheEvents = 'ics_cache_events_v1';
  static const _prefIcsLastSuccessAt = 'ics_last_success_at_v1';
  static const _prefIcsLastFailureAt = 'ics_last_failure_at_v1';
  static const _prefIcsLastFailureReason = 'ics_last_failure_reason_v1';
  static const _prefTimetablePath = 'timetable_image_path';

  static Future<BackupExportResult> exportToFile({String? targetPath}) async {
    final payload = await _buildPayload();

    final outPath = targetPath ?? await _defaultBackupPath();
    final outFile = File(outPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    final summary = _extractSummary(payload);
    await ChangeHistoryService.log(
      'Backup exported',
      detail: p.basename(outFile.path),
    );

    return BackupExportResult(filePath: outFile.path, summary: summary);
  }

  static Future<BackupImportResult> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('Backup file does not exist.');
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup format is invalid.');
    }

    final version = decoded['schemaVersion'];
    if (version is! int || version <= 0 || version > _schemaVersion) {
      throw const FormatException('Backup schema version is not supported.');
    }

    await NotificationService.I.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final todoBox = Hive.box<TodoItem>('todos');
    final courseBox = Hive.box<Course>('courses');
    final materialBox = Hive.box<CourseMaterial>('course_materials');
    final noteBox = Hive.box<String>('material_notes');
    final pageMemoBox = Hive.box<String>('material_page_memos');
    final historyBox = Hive.box<String>(ChangeHistoryService.boxName);
    final notifBox = Hive.box<int>('notif');

    await todoBox.clear();
    await courseBox.clear();
    await materialBox.clear();
    await noteBox.clear();
    await pageMemoBox.clear();
    await historyBox.clear();
    await notifBox.clear();

    final coursesRaw = _asList(decoded['courses']);
    for (final rawCourse in coursesRaw) {
      final m = _asMap(rawCourse);
      final id = m['id']?.toString() ?? '';
      final name = m['name']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      await courseBox.add(Course(id: id, name: name));
    }

    final todosRaw = _asList(decoded['todos']);
    for (final rawTodo in todosRaw) {
      final m = _asMap(rawTodo);
      final id = m['id']?.toString() ?? '';
      final title = m['title']?.toString() ?? '';
      if (id.isEmpty || title.isEmpty) continue;

      final dueAtMillis = _toInt(m['dueAtMillis']);
      final remindAtMillis = _toInt(m['remindAtMillis']);
      final completed = m['completed'] == true;
      final repeat = m['repeat']?.toString() ?? 'none';
      final priority = m['priority']?.toString() ?? 'none';

      await todoBox.add(
        TodoItem(
          id: id,
          title: title,
          dueAt: dueAtMillis == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(dueAtMillis),
          remindAt: remindAtMillis == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(remindAtMillis),
          completed: completed,
          repeatRule: TodoRepeatX.fromStorage(repeat),
          priorityLevel: TodoPriorityX.fromStorage(priority),
        ),
      );
    }

    final materialFiles = _asMap(decoded['materialFiles']);
    final materialsRaw = _asList(decoded['courseMaterials']);
    final materialRoot = await _materialRestoreRoot();
    await materialRoot.create(recursive: true);

    for (final rawMaterial in materialsRaw) {
      final m = _asMap(rawMaterial);
      final courseId = m['courseId']?.toString() ?? '';
      final fileName = m['fileName']?.toString() ?? '';
      final addedAtMillis = _toInt(m['addedAtMillis']) ?? 0;
      final relativePath = m['relativePath']?.toString() ?? '';

      if (courseId.isEmpty || fileName.isEmpty || relativePath.isEmpty) {
        continue;
      }

      final bytesBase64 = materialFiles[relativePath]?.toString() ?? '';
      if (bytesBase64.isEmpty) continue;

      final bytes = base64Decode(bytesBase64);
      final targetPath = p.join(materialRoot.path, _safePath(relativePath));
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsBytes(bytes, flush: true);

      await materialBox.add(
        CourseMaterial.hive(
          courseId: courseId,
          fileName: fileName,
          localPath: targetFile.path,
          addedAtMillis: addedAtMillis,
        ),
      );
    }

    final notesRaw = _asMap(decoded['materialNotes']);
    for (final entry in notesRaw.entries) {
      final value = entry.value?.toString();
      if (value == null) continue;
      await noteBox.put(entry.key.toString(), value);
    }

    final pageMemosRaw = _asMap(decoded['materialPageMemos']);
    for (final entry in pageMemosRaw.entries) {
      final value = entry.value?.toString();
      if (value == null) continue;
      await pageMemoBox.put(entry.key.toString(), value);
    }

    final historyRaw = _asList(decoded['changeHistory']);
    for (final entry in historyRaw) {
      final value = entry?.toString();
      if (value == null || value.isEmpty) continue;
      await historyBox.add(value);
    }

    final notifRaw = _asMap(decoded['notif']);
    for (final entry in notifRaw.entries) {
      final value = _toInt(entry.value);
      if (value == null) continue;
      await notifBox.put(entry.key, value);
    }
    if (!notifBox.containsKey('nextId')) {
      await notifBox.put('nextId', 1);
    }

    final settingsRaw = _asMap(decoded['settings']);

    final startTab = (_toInt(settingsRaw[_prefStartTab]) ?? 0).clamp(0, 3);
    final themeMode = settingsRaw[_prefThemeMode]?.toString() ?? 'system';
    final localeCode = settingsRaw[_prefLocaleCode]?.toString() ?? 'ko';

    await prefs.setInt(_prefStartTab, startTab);
    await prefs.setString(_prefThemeMode, themeMode);
    await prefs.setString(_prefLocaleCode, localeCode);
    await _putOrRemoveString(prefs, _prefIcsUrl, settingsRaw[_prefIcsUrl]);
    await _putOrRemoveString(
      prefs,
      _prefIcsCacheEvents,
      settingsRaw[_prefIcsCacheEvents],
    );
    await _putOrRemoveString(
      prefs,
      _prefIcsLastSuccessAt,
      settingsRaw[_prefIcsLastSuccessAt],
    );
    await _putOrRemoveString(
      prefs,
      _prefIcsLastFailureAt,
      settingsRaw[_prefIcsLastFailureAt],
    );
    await _putOrRemoveString(
      prefs,
      _prefIcsLastFailureReason,
      settingsRaw[_prefIcsLastFailureReason],
    );

    final timetableRaw = _asMap(decoded['timetable']);
    final timetableName = timetableRaw['fileName']?.toString();
    final timetableBytesBase64 = timetableRaw['bytesBase64']?.toString();

    if (timetableName != null &&
        timetableName.isNotEmpty &&
        timetableBytesBase64 != null &&
        timetableBytesBase64.isNotEmpty) {
      final bytes = base64Decode(timetableBytesBase64);
      final appDir = await getApplicationDocumentsDirectory();
      final timetablePath = p.join(
        appDir.path,
        'timetable_restored${p.extension(timetableName)}',
      );
      final timetableFile = File(timetablePath);
      await timetableFile.writeAsBytes(bytes, flush: true);
      await prefs.setString(_prefTimetablePath, timetableFile.path);
    } else {
      await prefs.remove(_prefTimetablePath);
    }

    for (final item in todoRepo.list()) {
      await todoRepo.update(item, logAction: false);
    }

    await HomeWidgetService.syncTodoSummary(todoBox.values);

    await ChangeHistoryService.log(
      'Backup restored',
      detail: p.basename(filePath),
    );

    final summary = _extractSummary(decoded);
    return BackupImportResult(
      summary: summary,
      startTab: startTab,
      themeMode: themeMode,
      localeCode: localeCode,
    );
  }

  static Future<Map<String, dynamic>> _buildPayload() async {
    final prefs = await SharedPreferences.getInstance();

    final todoBox = Hive.box<TodoItem>('todos');
    final courseBox = Hive.box<Course>('courses');
    final materialBox = Hive.box<CourseMaterial>('course_materials');
    final noteBox = Hive.box<String>('material_notes');
    final pageMemoBox = Hive.box<String>('material_page_memos');
    final historyBox = Hive.box<String>(ChangeHistoryService.boxName);
    final notifBox = Hive.box<int>('notif');

    final materialFiles = <String, String>{};
    final materials = <Map<String, dynamic>>[];

    for (var i = 0; i < materialBox.length; i++) {
      final material = materialBox.getAt(i);
      if (material == null) continue;

      final sourceFile = File(material.localPath);
      if (!await sourceFile.exists()) continue;

      final relativePath = p.join(
        _safePath(material.courseId),
        '${i}_${_safePath(material.fileName)}',
      );
      final bytes = await sourceFile.readAsBytes();
      materialFiles[relativePath] = base64Encode(bytes);

      materials.add({
        'courseId': material.courseId,
        'fileName': material.fileName,
        'addedAtMillis': material.addedAtMillis,
        'relativePath': relativePath,
      });
    }

    final timetable = await _readTimetablePayload(prefs);

    return {
      'app': 'CampusMate',
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        _prefStartTab: prefs.getInt(_prefStartTab) ?? 0,
        _prefThemeMode: prefs.getString(_prefThemeMode) ?? 'system',
        _prefLocaleCode: prefs.getString(_prefLocaleCode) ?? 'ko',
        _prefIcsUrl: prefs.getString(_prefIcsUrl),
        _prefIcsCacheEvents: prefs.getString(_prefIcsCacheEvents),
        _prefIcsLastSuccessAt: prefs.getString(_prefIcsLastSuccessAt),
        _prefIcsLastFailureAt: prefs.getString(_prefIcsLastFailureAt),
        _prefIcsLastFailureReason: prefs.getString(_prefIcsLastFailureReason),
      },
      'todos': [
        for (final t in todoBox.values)
          {
            'id': t.id,
            'title': t.title,
            'dueAtMillis': t.dueAtMillis,
            'completed': t.completed,
            'remindAtMillis': t.remindAtMillis,
            'repeat': t.repeat,
            'priority': t.priority,
          },
      ],
      'courses': [
        for (final c in courseBox.values) {'id': c.id, 'name': c.name},
      ],
      'courseMaterials': materials,
      'materialFiles': materialFiles,
      'materialNotes': _stringBoxToMap(noteBox),
      'materialPageMemos': _stringBoxToMap(pageMemoBox),
      'changeHistory': historyBox.values.toList(),
      'notif': _intBoxToMap(notifBox),
      'timetable': timetable,
    };
  }

  static BackupSummary _extractSummary(Map<String, dynamic> payload) {
    final todos = _asList(payload['todos']).length;
    final courses = _asList(payload['courses']).length;
    final materials = _asList(payload['courseMaterials']).length;
    return BackupSummary(todos: todos, courses: courses, materials: materials);
  }

  static Future<Map<String, dynamic>> _readTimetablePayload(
    SharedPreferences prefs,
  ) async {
    final timetablePath = prefs.getString(_prefTimetablePath);
    if (timetablePath == null || timetablePath.isEmpty) {
      return const <String, dynamic>{};
    }

    final file = File(timetablePath);
    if (!await file.exists()) {
      return const <String, dynamic>{};
    }

    final bytes = await file.readAsBytes();
    return {
      'fileName': p.basename(file.path),
      'bytesBase64': base64Encode(bytes),
    };
  }

  static Map<String, String> _stringBoxToMap(Box<String> box) {
    final out = <String, String>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        out[key.toString()] = value;
      }
    }
    return out;
  }

  static Map<String, int> _intBoxToMap(Box<int> box) {
    final out = <String, int>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        out[key.toString()] = value;
      }
    }
    return out;
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    return const [];
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, v) => out[key.toString()] = v);
      return out;
    }
    return const {};
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Future<void> _putOrRemoveString(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    final text = value?.toString();
    if (text == null || text.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, text);
    }
  }

  static Future<String> _defaultBackupPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, 'backups'));
    await backupDir.create(recursive: true);

    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    return p.join(backupDir.path, 'campusmate_backup_$stamp.json');
  }

  static Future<Directory> _materialRestoreRoot() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'course_materials_restored'));
  }

  static String _safePath(String raw) {
    final out = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (out.isEmpty) return 'item';
    return out;
  }

  static String _two(int x) => x.toString().padLeft(2, '0');
}
