import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/courses/course.dart';
import '../features/courses/course_material.dart';
import '../features/todo/todo_model.dart';
import '../features/todo/todo_repo.dart';
import 'calendar_range_settings.dart';
import 'change_history_service.dart';
import 'home_widget_service.dart';
import 'notification_service.dart';
import 'safety_limits.dart';
import 'theme.dart';

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
  final bool encrypted;

  const BackupExportResult({
    required this.filePath,
    required this.summary,
    required this.encrypted,
  });
}

class BackupImportResult {
  final BackupSummary summary;
  final int startTab;
  final String themeMode;
  final String themePresetKey;
  final CampusMateCustomPalette customThemePalette;
  final String localeCode;
  final bool encrypted;

  const BackupImportResult({
    required this.summary,
    required this.startTab,
    required this.themeMode,
    required this.themePresetKey,
    required this.customThemePalette,
    required this.localeCode,
    required this.encrypted,
  });
}

class DataBackupService {
  DataBackupService._();

  static const _schemaVersion = 1;
  static const _encryptedFormat = 'encrypted_v1';

  static const _prefStartTab = 'start_tab_index';
  static const _prefThemeMode = 'theme_mode';
  static const _prefThemePreset = 'theme_preset_key';
  static const _prefThemeCustomPalette = 'theme_custom_palette_v1';
  static const _prefLocaleCode = 'locale_code';
  static const _prefCalendarRangeMode = CalendarRangeSettings.prefKeyMode;
  static const _prefCalendarRangeAmount = CalendarRangeSettings.prefKeyAmount;
  static const _prefIcsUrl = 'ics_feed_url';
  static const _prefIcsCacheEvents = 'ics_cache_events_v1';
  static const _prefIcsLastSuccessAt = 'ics_last_success_at_v1';
  static const _prefIcsLastFailureAt = 'ics_last_failure_at_v1';
  static const _prefIcsLastFailureReason = 'ics_last_failure_reason_v1';
  static const _prefTimetablePath = 'timetable_image_path';

  static const _prefBackupPinSalt = 'backup_pin_salt_v1';
  static const _prefBackupPinHash = 'backup_pin_hash_v1';

  static const _kdfIterations = 120000;
  static const _kdfBits = 256;
  static const _pinMinLength = 4;
  static const _legacyPinMinLength = 4;
  static const _pinHashPrefix = 'pbkdf2_sha256_v1:';

  static int get pinMinLength => _pinMinLength;

  static Future<bool> hasBackupPin() async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(_prefBackupPinSalt);
    final hash = prefs.getString(_prefBackupPinHash);
    return salt != null && hash != null && salt.isNotEmpty && hash.isNotEmpty;
  }

  static Future<void> setBackupPin(String pin) async {
    final normalized = pin.trim();
    if (normalized.length < _pinMinLength) {
      throw FormatException('PIN must be at least $_pinMinLength digits.');
    }

    final prefs = await SharedPreferences.getInstance();
    final salt = _randomBytes(16);
    final hash = await _hashPin(normalized, salt);

    await prefs.setString(_prefBackupPinSalt, base64Encode(salt));
    await prefs.setString(_prefBackupPinHash, hash);
  }

  static Future<bool> verifyBackupPin(String pin) async {
    final normalized = pin.trim();
    if (normalized.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final saltBase64 = prefs.getString(_prefBackupPinSalt);
    final hash = prefs.getString(_prefBackupPinHash);
    if (saltBase64 == null || hash == null) return false;

    final salt = base64Decode(saltBase64);

    if (_isPbkdf2PinHash(hash)) {
      final computed = await _hashPin(normalized, salt);
      return _constantTimeEquals(computed, hash);
    }

    final legacyHash = await _hashPinLegacySha256(normalized, salt);
    final matchedLegacy = _constantTimeEquals(legacyHash, hash);
    if (!matchedLegacy) return false;

    // Upgrade legacy verifier hash to PBKDF2 after first successful check.
    final upgradedHash = await _hashPin(normalized, salt);
    await prefs.setString(_prefBackupPinHash, upgradedHash);
    return true;
  }

  static Future<void> clearBackupPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefBackupPinSalt);
    await prefs.remove(_prefBackupPinHash);
  }

  static Future<bool> isEncryptedBackupFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    try {
      final decoded = jsonDecode(await file.readAsString());
      final map = _asMap(decoded);
      return map['backupFormat'] == _encryptedFormat;
    } catch (_) {
      return false;
    }
  }

  static Future<BackupExportResult> exportToFile({
    String? targetPath,
    String? pin,
  }) async {
    final payload = await _buildPayload();

    final normalizedPin = pin?.trim();
    final encrypted = normalizedPin != null && normalizedPin.isNotEmpty;

    final outObject = encrypted
        ? await _encryptPayload(payload, normalizedPin)
        : payload;

    final outPath = targetPath ?? await _defaultBackupPath();
    final outFile = File(outPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(outObject),
    );
    final writtenBytes = await outFile.length();
    if (writtenBytes > SafetyLimits.maxBackupFileBytes) {
      await outFile.delete();
      throw FormatException(
        'Backup file is too large (limit ${_mb(SafetyLimits.maxBackupFileBytes)}MB).',
      );
    }

    final summary = _extractSummary(payload);
    await ChangeHistoryService.log(
      'Backup exported',
      detail: encrypted
          ? '${p.basename(outFile.path)} (encrypted)'
          : p.basename(outFile.path),
    );

    return BackupExportResult(
      filePath: outFile.path,
      summary: summary,
      encrypted: encrypted,
    );
  }

  static Future<BackupImportResult> importFromFile(
    String filePath, {
    String? pin,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('Backup file does not exist.');
    }
    final fileBytes = await file.length();
    if (fileBytes > SafetyLimits.maxBackupFileBytes) {
      throw FormatException(
        'Backup file is too large (limit ${_mb(SafetyLimits.maxBackupFileBytes)}MB).',
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    final decodedMap = _asMap(decoded);
    if (decodedMap.isEmpty) {
      throw const FormatException('Backup format is invalid.');
    }

    final encrypted = decodedMap['backupFormat'] == _encryptedFormat;
    final payload = await _decodePayloadForImport(decodedMap, pin: pin);
    _validatePayloadLimits(payload);

    final version = payload['schemaVersion'];
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

    final coursesRaw = _asList(payload['courses']);
    for (final rawCourse in coursesRaw) {
      final m = _asMap(rawCourse);
      final id = m['id']?.toString() ?? '';
      final name = _clampText(
        m['name']?.toString() ?? '',
        SafetyLimits.maxCourseNameChars,
      );
      final memo = _clampText(
        m['memo']?.toString() ?? '',
        SafetyLimits.maxCourseMemoChars,
      );
      if (id.isEmpty || name.isEmpty) continue;

      final tags = <String>[];
      final seenTagKeys = <String>{};
      final tagsRaw = m['tags'];
      if (tagsRaw is List) {
        for (final rawTag in tagsRaw) {
          var tag = rawTag?.toString().trim() ?? '';
          if (tag.isEmpty) continue;
          if (tag.length > SafetyLimits.maxCourseTagChars) {
            tag = tag.substring(0, SafetyLimits.maxCourseTagChars).trim();
          }
          if (tag.isEmpty) continue;
          final key = tag.toLowerCase();
          if (!seenTagKeys.add(key)) continue;
          tags.add(tag);
          if (tags.length >= SafetyLimits.maxCourseTagsPerCourse) break;
        }
      }

      await courseBox.add(Course(id: id, name: name, memo: memo, tags: tags));
    }

    final todosRaw = _asList(payload['todos']);
    for (final rawTodo in todosRaw) {
      final m = _asMap(rawTodo);
      final id = m['id']?.toString() ?? '';
      final title = _clampText(
        m['title']?.toString() ?? '',
        SafetyLimits.maxTodoTitleChars,
      );
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

    final materialFiles = _asMap(payload['materialFiles']);
    final materialsRaw = _asList(payload['courseMaterials']);
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

      List<int> bytes;
      try {
        bytes = base64Decode(bytesBase64);
      } catch (_) {
        continue;
      }
      if (bytes.length > SafetyLimits.maxBackupMaterialFileBytes) {
        continue;
      }
      final targetPath = p.join(
        materialRoot.path,
        _safeRelativePath(relativePath),
      );
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

    final notesRaw = _asMap(payload['materialNotes']);
    var importedNoteCount = 0;
    for (final entry in notesRaw.entries) {
      if (importedNoteCount >= SafetyLimits.maxBackupMaterials) break;
      final value = entry.value?.toString();
      if (value == null) continue;
      final safeValue = _clampText(value, SafetyLimits.maxOverallNoteChars);
      if (safeValue.isEmpty) continue;
      await noteBox.put(entry.key.toString(), safeValue);
      importedNoteCount++;
    }

    final pageMemosRaw = _asMap(payload['materialPageMemos']);
    var importedPageMemoCount = 0;
    for (final entry in pageMemosRaw.entries) {
      if (importedPageMemoCount >= SafetyLimits.maxBackupMaterials) break;
      final value = entry.value?.toString();
      if (value == null) continue;
      final safeValue = _clampText(value, SafetyLimits.maxPageMemoPayloadChars);
      if (safeValue.isEmpty) continue;
      await pageMemoBox.put(entry.key.toString(), safeValue);
      importedPageMemoCount++;
    }

    final historyRaw = _asList(payload['changeHistory']);
    for (final entry in historyRaw.take(SafetyLimits.maxBackupHistoryEntries)) {
      final value = entry?.toString();
      if (value == null || value.isEmpty) continue;
      await historyBox.add(value);
    }

    final notifRaw = _asMap(payload['notif']);
    for (final entry in notifRaw.entries) {
      final value = _toInt(entry.value);
      if (value == null) continue;
      await notifBox.put(entry.key, value);
    }
    if (!notifBox.containsKey('nextId')) {
      await notifBox.put('nextId', 1);
    }

    final settingsRaw = _asMap(payload['settings']);

    final startTab = (_toInt(settingsRaw[_prefStartTab]) ?? 0).clamp(0, 4);
    final themeMode = settingsRaw[_prefThemeMode]?.toString() ?? 'system';
    final rawThemePreset =
        settingsRaw[_prefThemePreset]?.toString() ??
        CampusMateTheme.defaultPaletteKey;
    final themePresetKey = CampusMateTheme.isValidPaletteKey(rawThemePreset)
        ? rawThemePreset
        : CampusMateTheme.defaultPaletteKey;
    final customThemePalette = CampusMateCustomPalette.fromStorageMap(
      _asMap(settingsRaw[_prefThemeCustomPalette]),
    );
    final localeCode = settingsRaw[_prefLocaleCode]?.toString() ?? 'ko';
    final calendarRangeMode = CalendarRangeSettings.parseMode(
      settingsRaw[_prefCalendarRangeMode]?.toString(),
    );
    final calendarRangeAmount = CalendarRangeSettings.normalizeAmount(
      calendarRangeMode,
      _toInt(settingsRaw[_prefCalendarRangeAmount]),
    );

    await prefs.setInt(_prefStartTab, startTab);
    await prefs.setString(_prefThemeMode, themeMode);
    await prefs.setString(_prefThemePreset, themePresetKey);
    await prefs.setString(
      _prefThemeCustomPalette,
      jsonEncode(customThemePalette.toStorageMap()),
    );
    await prefs.setString(_prefLocaleCode, localeCode);
    await prefs.setString(
      _prefCalendarRangeMode,
      CalendarRangeSettings.modeToStorage(calendarRangeMode),
    );
    await prefs.setInt(_prefCalendarRangeAmount, calendarRangeAmount);
    CalendarRangeSettings.notifier.value = CalendarRangeConfig(
      mode: calendarRangeMode,
      amount: calendarRangeAmount,
    );
    final importedIcsUrl = _normalizeHttpsUrl(settingsRaw[_prefIcsUrl]);
    if (importedIcsUrl == null) {
      await prefs.remove(_prefIcsUrl);
      await prefs.remove(_prefIcsCacheEvents);
      await prefs.remove(_prefIcsLastSuccessAt);
      await prefs.remove(_prefIcsLastFailureAt);
      await prefs.remove(_prefIcsLastFailureReason);
    } else {
      await prefs.setString(_prefIcsUrl, importedIcsUrl);
      // Force fresh sync after restore instead of trusting cached remote payload.
      await prefs.remove(_prefIcsCacheEvents);
      await prefs.remove(_prefIcsLastSuccessAt);
      await prefs.remove(_prefIcsLastFailureAt);
      await prefs.remove(_prefIcsLastFailureReason);
    }

    final timetableRaw = _asMap(payload['timetable']);
    final timetableName = timetableRaw['fileName']?.toString();
    final timetableBytesBase64 = timetableRaw['bytesBase64']?.toString();

    if (timetableName != null &&
        timetableName.isNotEmpty &&
        timetableBytesBase64 != null &&
        timetableBytesBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(timetableBytesBase64);
        if (bytes.length <= SafetyLimits.maxTimetableImageBytes) {
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
      } catch (_) {
        await prefs.remove(_prefTimetablePath);
      }
    } else {
      await prefs.remove(_prefTimetablePath);
    }

    for (final item in todoRepo.list()) {
      await todoRepo.update(item, logAction: false);
    }

    await HomeWidgetService.syncLocaleCode(localeCode);
    await HomeWidgetService.syncTodoSummary(todoBox.values);
    await HomeWidgetService.syncTimetableSummary(courseBox.values);

    await ChangeHistoryService.log(
      'Backup restored',
      detail: encrypted
          ? '${p.basename(filePath)} (encrypted)'
          : p.basename(filePath),
    );

    final summary = _extractSummary(payload);
    return BackupImportResult(
      summary: summary,
      startTab: startTab,
      themeMode: themeMode,
      themePresetKey: themePresetKey,
      customThemePalette: customThemePalette,
      localeCode: localeCode,
      encrypted: encrypted,
    );
  }

  static Future<Map<String, dynamic>> _decodePayloadForImport(
    Map<String, dynamic> decodedMap, {
    String? pin,
  }) async {
    final isEncrypted = decodedMap['backupFormat'] == _encryptedFormat;
    if (!isEncrypted) {
      return decodedMap;
    }

    final normalizedPin = pin?.trim() ?? '';
    if (normalizedPin.isEmpty) {
      throw const FormatException('PIN is required for encrypted backup.');
    }

    final saltBase64 = decodedMap['saltBase64']?.toString() ?? '';
    final nonceBase64 = decodedMap['nonceBase64']?.toString() ?? '';
    final cipherTextBase64 = decodedMap['cipherTextBase64']?.toString() ?? '';
    final macBase64 = decodedMap['macBase64']?.toString() ?? '';

    if (saltBase64.isEmpty ||
        nonceBase64.isEmpty ||
        cipherTextBase64.isEmpty ||
        macBase64.isEmpty) {
      throw const FormatException('Encrypted backup is malformed.');
    }

    final salt = base64Decode(saltBase64);
    final nonce = base64Decode(nonceBase64);
    final cipherText = base64Decode(cipherTextBase64);
    final macBytes = base64Decode(macBase64);
    if (cipherText.length > SafetyLimits.maxBackupFileBytes) {
      throw const FormatException('Encrypted backup is too large.');
    }

    final secretKey = await _deriveAesKey(normalizedPin, salt);
    final algorithm = AesGcm.with256bits();

    try {
      final clearBytes = await algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
      final clearText = utf8.decode(clearBytes);
      final clearDecoded = jsonDecode(clearText);
      final payload = _asMap(clearDecoded);
      if (payload.isEmpty) {
        throw const FormatException('Decrypted backup payload is invalid.');
      }
      return payload;
    } on SecretBoxAuthenticationError {
      throw const FormatException('Incorrect PIN or corrupted backup file.');
    }
  }

  static Future<Map<String, dynamic>> _encryptPayload(
    Map<String, dynamic> payload,
    String pin,
  ) async {
    final normalizedPin = pin.trim();
    if (normalizedPin.length < _legacyPinMinLength) {
      throw const FormatException('PIN must be at least 4 digits.');
    }

    final plaintext = utf8.encode(jsonEncode(payload));
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveAesKey(normalizedPin, salt);

    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'app': 'CampusMate',
      'backupFormat': _encryptedFormat,
      'schemaVersion': _schemaVersion,
      'exportedAt': payload['exportedAt'] ?? DateTime.now().toIso8601String(),
      'kdf': {
        'algorithm': 'pbkdf2-hmac-sha256',
        'iterations': _kdfIterations,
        'bits': _kdfBits,
      },
      'cipher': 'aes-gcm-256',
      'saltBase64': base64Encode(salt),
      'nonceBase64': base64Encode(nonce),
      'cipherTextBase64': base64Encode(secretBox.cipherText),
      'macBase64': base64Encode(secretBox.mac.bytes),
    };
  }

  static Future<SecretKey> _deriveAesKey(String pin, List<int> salt) {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: _kdfBits,
    );
    return kdf.deriveKeyFromPassword(password: pin, nonce: salt);
  }

  static Future<String> _hashPin(String pin, List<int> salt) async {
    final derived = await _deriveAesKey(pin, salt);
    final bytes = await derived.extractBytes();
    return '$_pinHashPrefix${base64Encode(bytes)}';
  }

  static bool _isPbkdf2PinHash(String hash) {
    return hash.startsWith(_pinHashPrefix);
  }

  static Future<String> _hashPinLegacySha256(String pin, List<int> salt) async {
    final hash = await Sha256().hash([...salt, ...utf8.encode(pin)]);
    return base64Encode(hash.bytes);
  }

  static bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    var diff = aBytes.length ^ bBytes.length;
    final maxLen = max(aBytes.length, bBytes.length);
    for (var i = 0; i < maxLen; i++) {
      final av = i < aBytes.length ? aBytes[i] : 0;
      final bv = i < bBytes.length ? bBytes[i] : 0;
      diff |= av ^ bv;
    }
    return diff == 0;
  }

  static List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
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

    if (todoBox.length > SafetyLimits.maxBackupTodos) {
      throw FormatException(
        'Too many todos to export (limit ${SafetyLimits.maxBackupTodos}).',
      );
    }
    if (courseBox.length > SafetyLimits.maxBackupCourses) {
      throw FormatException(
        'Too many courses to export (limit ${SafetyLimits.maxBackupCourses}).',
      );
    }
    if (materialBox.length > SafetyLimits.maxBackupMaterials) {
      throw FormatException(
        'Too many course materials to export (limit ${SafetyLimits.maxBackupMaterials}).',
      );
    }

    final materialFiles = <String, String>{};
    final materials = <Map<String, dynamic>>[];

    for (var i = 0; i < materialBox.length; i++) {
      final material = materialBox.getAt(i);
      if (material == null) continue;

      final sourceFile = File(material.localPath);
      if (!await sourceFile.exists()) continue;

      final relativePath = p.join(
        _safePathSegment(material.courseId),
        '${i}_${_safePathSegment(material.fileName)}',
      );
      final sourceBytes = await sourceFile.length();
      if (sourceBytes > SafetyLimits.maxBackupMaterialFileBytes) {
        throw FormatException(
          'Material is too large for backup: ${material.fileName} (limit ${_mb(SafetyLimits.maxBackupMaterialFileBytes)}MB).',
        );
      }
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
        _prefThemePreset:
            prefs.getString(_prefThemePreset) ??
            CampusMateTheme.defaultPaletteKey,
        _prefThemeCustomPalette: _readCustomPalettePref(prefs).toStorageMap(),
        _prefLocaleCode: prefs.getString(_prefLocaleCode) ?? 'ko',
        _prefCalendarRangeMode:
            prefs.getString(_prefCalendarRangeMode) ??
            CalendarRangeSettings.modeToStorage(
              CalendarRangeSettings.defaultValue.mode,
            ),
        _prefCalendarRangeAmount:
            prefs.getInt(_prefCalendarRangeAmount) ??
            CalendarRangeSettings.defaultValue.amount,
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
        for (final c in courseBox.values)
          {'id': c.id, 'name': c.name, 'memo': c.memo, 'tags': c.tags},
      ],
      'courseMaterials': materials,
      'materialFiles': materialFiles,
      'materialNotes': _stringBoxToMap(
        noteBox,
        maxEntries: SafetyLimits.maxBackupMaterials,
        maxValueChars: SafetyLimits.maxOverallNoteChars,
      ),
      'materialPageMemos': _stringBoxToMap(
        pageMemoBox,
        maxEntries: SafetyLimits.maxBackupMaterials,
        maxValueChars: SafetyLimits.maxPageMemoPayloadChars,
      ),
      'changeHistory': historyBox.values
          .toList()
          .take(SafetyLimits.maxBackupHistoryEntries)
          .toList(),
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

    final fileBytes = await file.length();
    if (fileBytes > SafetyLimits.maxTimetableImageBytes) {
      return const <String, dynamic>{};
    }

    final bytes = await file.readAsBytes();
    return {
      'fileName': p.basename(file.path),
      'bytesBase64': base64Encode(bytes),
    };
  }

  static Map<String, String> _stringBoxToMap(
    Box<String> box, {
    int? maxEntries,
    int? maxValueChars,
  }) {
    final out = <String, String>{};
    for (final key in box.keys) {
      if (maxEntries != null && out.length >= maxEntries) break;
      final value = box.get(key);
      if (value != null) {
        out[key.toString()] = _clampText(value, maxValueChars);
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

  static void _validatePayloadLimits(Map<String, dynamic> payload) {
    final todoCount = _asList(payload['todos']).length;
    final courseCount = _asList(payload['courses']).length;
    final materialCount = _asList(payload['courseMaterials']).length;
    final historyCount = _asList(payload['changeHistory']).length;
    final noteCount = _asMap(payload['materialNotes']).length;
    final pageMemoCount = _asMap(payload['materialPageMemos']).length;

    if (todoCount > SafetyLimits.maxBackupTodos) {
      throw FormatException(
        'Backup has too many todos (limit ${SafetyLimits.maxBackupTodos}).',
      );
    }
    if (courseCount > SafetyLimits.maxBackupCourses) {
      throw FormatException(
        'Backup has too many courses (limit ${SafetyLimits.maxBackupCourses}).',
      );
    }
    if (materialCount > SafetyLimits.maxBackupMaterials) {
      throw FormatException(
        'Backup has too many materials (limit ${SafetyLimits.maxBackupMaterials}).',
      );
    }
    if (historyCount > SafetyLimits.maxBackupHistoryEntries) {
      throw FormatException(
        'Backup has too many history entries (limit ${SafetyLimits.maxBackupHistoryEntries}).',
      );
    }
    if (noteCount > SafetyLimits.maxBackupMaterials) {
      throw FormatException(
        'Backup has too many material notes (limit ${SafetyLimits.maxBackupMaterials}).',
      );
    }
    if (pageMemoCount > SafetyLimits.maxBackupMaterials) {
      throw FormatException(
        'Backup has too many material memo entries (limit ${SafetyLimits.maxBackupMaterials}).',
      );
    }
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

  static CampusMateCustomPalette _readCustomPalettePref(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_prefThemeCustomPalette);
    if (raw == null || raw.trim().isEmpty) {
      return CampusMateCustomPalette.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return CampusMateCustomPalette.fromStorageMap(decoded);
      }
    } catch (_) {
      // Fall through to defaults.
    }
    return CampusMateCustomPalette.defaults;
  }

  static String? _normalizeHttpsUrl(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    if (text.length > 2048) return null;

    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) return null;

    return uri.replace(fragment: '').toString();
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

  static String _clampText(String text, int? maxChars) {
    final normalized = text.trim();
    if (maxChars == null || maxChars <= 0) return normalized;
    if (normalized.length <= maxChars) return normalized;
    return normalized.substring(0, maxChars);
  }

  static String _safePathSegment(String raw) {
    final out = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (out.isEmpty || out == '.' || out == '..') return 'item';
    const maxSegmentChars = 80;
    if (out.length <= maxSegmentChars) return out;
    return out.substring(0, maxSegmentChars);
  }

  static String _safeRelativePath(String raw) {
    final normalized = raw.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map(_safePathSegment)
        .toList();
    if (parts.isEmpty) return 'item';
    return p.joinAll(parts);
  }

  static String _two(int x) => x.toString().padLeft(2, '0');

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);
}
