import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_link.dart';

class NotificationDiagnostics {
  final bool? notificationsEnabled;
  final bool? canScheduleExactNotifications;
  final int pendingCount;

  const NotificationDiagnostics({
    required this.notificationsEnabled,
    required this.canScheduleExactNotifications,
    required this.pendingCount,
  });
}

class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // New channel id to avoid inheriting stale channel settings on updated installs.
  static const String _channelId = 'todo_reminders_v2';
  static const String _channelName = 'Todo Reminders';
  static const String _channelDesc = 'Todo reminder notifications';

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    tzdata.initializeTimeZones();
    try {
      final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
      final tzName = tzInfo is String
          ? tzInfo
          : (tzInfo.identifier as String? ?? 'Asia/Seoul');
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        if (kDebugMode) {
          debugPrint('notification tapped payload=${r.payload}');
        }

        final raw = r.payload;
        if (raw == null || raw.isEmpty) return;

        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final type = m['type'];
          if (type == 'todo') {
            final todoId = m['todoId'];
            if (todoId is String && todoId.isNotEmpty) {
              AppLink.openTodo(todoId);
            }
          }
        } catch (_) {
          // ignore malformed payload
        }
      },
    );

    _inited = true;
  }

  Future<bool> requestPermissions() async {
    var granted = true;

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      final enabled = await androidImpl.areNotificationsEnabled();
      if (enabled != true) {
        final requested = await androidImpl.requestNotificationsPermission();
        granted = (requested ?? false) && granted;
      }

      if (kDebugMode) {
        final canExact = await androidImpl.canScheduleExactNotifications();
        debugPrint('canScheduleExactNotifications(initial)=$canExact');
      }
    }

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      final requested = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (requested != null) {
        granted = requested && granted;
      }
    }

    return granted;
  }

  Future<bool?> requestExactAlarmPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) return null;
    await androidImpl.requestExactAlarmsPermission();
    return androidImpl.canScheduleExactNotifications();
  }

  Future<NotificationDiagnostics> diagnostics() async {
    bool? notificationsEnabled;
    bool? canExact;

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      notificationsEnabled = await androidImpl.areNotificationsEnabled();
      canExact = await androidImpl.canScheduleExactNotifications();
    }

    final pending = await _plugin.pendingNotificationRequests();
    return NotificationDiagnostics(
      notificationsEnabled: notificationsEnabled,
      canScheduleExactNotifications: canExact,
      pendingCount: pending.length,
    );
  }

  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(id: notificationId);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> scheduleTodo({
    required int notificationId,
    required String todoId,
    required String title,
    required DateTime remindAt,
  }) async {
    await requestPermissions();

    final now = DateTime.now();
    final effectiveRemindAt = remindAt.isAfter(now)
        ? remindAt
        : now.add(const Duration(seconds: 5));

    final scheduled = tz.TZDateTime.from(effectiveRemindAt, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final payload = jsonEncode({'type': 'todo', 'todoId': todoId});

    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      var canExact = await androidImpl.canScheduleExactNotifications();
      if (canExact != true) {
        // Android 14+ may require explicit exact alarm grant from settings.
        final requested = await androidImpl.requestExactAlarmsPermission();
        canExact = await androidImpl.canScheduleExactNotifications();
        if (kDebugMode) {
          debugPrint(
            'requestExactAlarmsPermission=$requested, canExactAfter=$canExact',
          );
        }
      }
      if (canExact == true) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    }

    Future<void> scheduleWith(AndroidScheduleMode scheduleMode) {
      return _plugin.zonedSchedule(
        id: notificationId,
        title: 'Todo reminder',
        body: title,
        scheduledDate: scheduled,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: null,
      );
    }

    try {
      await scheduleWith(mode);
      if (kDebugMode) {
        final pending = await _plugin.pendingNotificationRequests();
        debugPrint(
          'scheduled todo notif id=$notificationId mode=$mode at=${scheduled.toLocal()} pending=${pending.length}',
        );
      }
    } catch (_) {
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
        if (kDebugMode) {
          debugPrint(
            'exact schedule failed for id=$notificationId, fell back to inexactAllowWhileIdle',
          );
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> scheduleDebugNotification({
    Duration after = const Duration(seconds: 15),
  }) async {
    final now = DateTime.now();
    final remindAt = now.add(after);
    final scheduled = tz.TZDateTime.from(remindAt, tz.local);
    const notificationId = 990001;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      final canExact = await androidImpl.canScheduleExactNotifications();
      if (canExact == true) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'CampusMate',
      body: 'Notification self-test',
      scheduledDate: scheduled,
      notificationDetails: details,
      payload: jsonEncode({'type': 'debug'}),
      androidScheduleMode: mode,
      matchDateTimeComponents: null,
    );
  }
}
