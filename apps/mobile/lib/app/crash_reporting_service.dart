import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService I = CrashReportingService._();

  static const String _dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );
  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_SENTRY',
    defaultValue: false,
  );

  bool get isEnabled => _enabled && _dsn.trim().isNotEmpty;

  Future<void> runAppWithReporting(Widget app) async {
    if (!isEnabled) {
      _bindFallbackErrorHooks();
      runZonedGuarded(() => runApp(app), (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('uncaught zone error: $error');
        }
      });
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.environment = kReleaseMode ? 'release' : 'debug';
      options.tracesSampleRate = 0.05;
      options.profilesSampleRate = 0.0;
    }, appRunner: () => runApp(app));
  }

  Future<void> captureTestEvent() async {
    if (!isEnabled) return;
    await Sentry.captureMessage(
      'CampusMate crash-reporting smoke test',
      level: SentryLevel.info,
    );
  }

  void _bindFallbackErrorHooks() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
      if (kDebugMode) {
        debugPrint('flutter error: ${details.exceptionAsString()}');
      }
    };
  }
}
