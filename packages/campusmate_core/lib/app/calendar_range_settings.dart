import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CalendarRangeMode { weeks, months }

@immutable
class CalendarRangeConfig {
  final CalendarRangeMode mode;
  final int amount;

  const CalendarRangeConfig({required this.mode, required this.amount});

  CalendarRangeConfig copyWith({CalendarRangeMode? mode, int? amount}) {
    return CalendarRangeConfig(
      mode: mode ?? this.mode,
      amount: amount ?? this.amount,
    );
  }
}

class CalendarRangeSettings {
  CalendarRangeSettings._();

  static const prefKeyMode = 'calendar_range_mode_v1';
  static const prefKeyAmount = 'calendar_range_amount_v1';

  static const List<int> weekAmountOptions = [4, 8, 12, 24, 52];
  static const List<int> monthAmountOptions = [3, 6, 12, 24, 36];
  static const CalendarRangeConfig defaultValue = CalendarRangeConfig(
    mode: CalendarRangeMode.months,
    amount: 12,
  );

  static final ValueNotifier<CalendarRangeConfig> notifier =
      ValueNotifier<CalendarRangeConfig>(defaultValue);

  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final mode = parseMode(prefs.getString(prefKeyMode));
    final amount = normalizeAmount(mode, prefs.getInt(prefKeyAmount));
    notifier.value = CalendarRangeConfig(mode: mode, amount: amount);
    _loaded = true;
  }

  static Future<void> setMode(CalendarRangeMode mode) async {
    final current = notifier.value;
    final next = CalendarRangeConfig(
      mode: mode,
      amount: normalizeAmount(mode, current.amount),
    );
    await _save(next);
  }

  static Future<void> setAmount(int amount) async {
    final current = notifier.value;
    final next = current.copyWith(
      amount: normalizeAmount(current.mode, amount),
    );
    await _save(next);
  }

  static List<int> amountOptions(CalendarRangeMode mode) {
    return mode == CalendarRangeMode.weeks
        ? weekAmountOptions
        : monthAmountOptions;
  }

  static CalendarRangeMode parseMode(String? raw) {
    return raw == 'weeks' ? CalendarRangeMode.weeks : CalendarRangeMode.months;
  }

  static String modeToStorage(CalendarRangeMode mode) {
    return mode == CalendarRangeMode.weeks ? 'weeks' : 'months';
  }

  static int normalizeAmount(CalendarRangeMode mode, int? rawAmount) {
    final options = amountOptions(mode);
    if (rawAmount == null) {
      return options.contains(defaultValue.amount)
          ? defaultValue.amount
          : options.first;
    }
    return _nearestOption(options, rawAmount);
  }

  static DateTime firstDayFor(DateTime anchor, CalendarRangeConfig config) {
    final now = DateTime(anchor.year, anchor.month, anchor.day);
    if (config.mode == CalendarRangeMode.weeks) {
      return now.subtract(Duration(days: config.amount * 7));
    }
    return DateTime(now.year, now.month - config.amount, 1);
  }

  static DateTime lastDayFor(DateTime anchor, CalendarRangeConfig config) {
    final now = DateTime(anchor.year, anchor.month, anchor.day);
    if (config.mode == CalendarRangeMode.weeks) {
      return now.add(Duration(days: config.amount * 7));
    }
    return DateTime(now.year, now.month + config.amount + 1, 0);
  }

  static Future<void> _save(CalendarRangeConfig value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyMode, modeToStorage(value.mode));
    await prefs.setInt(prefKeyAmount, value.amount);
    notifier.value = value;
  }

  static int _nearestOption(List<int> options, int value) {
    var nearest = options.first;
    var bestDistance = (nearest - value).abs();
    for (final option in options.skip(1)) {
      final distance = (option - value).abs();
      if (distance < bestDistance) {
        nearest = option;
        bestDistance = distance;
      }
    }
    return nearest;
  }
}
