import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'todo_reminders';
  static const String _channelName = 'Todo Reminders';
  static const String _channelDesc = 'Todo reminder notifications';

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    // timezone init
    tzdata.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone(); // TimezoneInfo
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
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
      },
    );

    // Android 13+ permission
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    // iOS permission (안드로이드만 써도 넣어두면 안전)
    final iosImpl =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _inited = true;
  }

  Future<void> cancel(int notificationId) async {
    // 네 버전은 named 'id' 형태로 보임
    await _plugin.cancel(id: notificationId);
  }

  Future<void> scheduleTodo({
    required int notificationId,
    required String todoId,
    required String title,
    required DateTime remindAt,
  }) async {
    if (remindAt.isBefore(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(remindAt, tz.local);

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

    final payload = jsonEncode({
      'type': 'todo',
      'todoId': todoId,
    });

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Todo 리마인더',
      body: title,
      scheduledDate: scheduled,
      notificationDetails: details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }
}
