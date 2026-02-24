import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService I = CrashReportingService._();

  bool get isEnabled => false;

  Future<void> runAppWithReporting(Widget app) async {
    _bindFallbackErrorHooks();
    runApp(app);
  }

  Future<void> captureTestEvent() async {}

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

    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final previousOnError = dispatcher.onError;
    dispatcher.onError = (error, stackTrace) {
      if (previousOnError != null && previousOnError(error, stackTrace)) {
        return true;
      }
      if (kDebugMode) {
        debugPrint('uncaught async error: $error');
      }
      return false;
    };
  }
}
