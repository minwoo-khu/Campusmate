class QuickCaptureParseResult {
  final String title;
  final DateTime? dueAt;
  final DateTime? remindAt;
  final bool parsed;

  const QuickCaptureParseResult({
    required this.title,
    required this.dueAt,
    required this.remindAt,
    required this.parsed,
  });
}

class QuickCaptureParser {
  QuickCaptureParser._();

  static QuickCaptureParseResult parse(String input, {DateTime? now}) {
    final baseNow = now ?? DateTime.now();
    var rest = input.trim();

    DateTime? date;
    DateTime? timeBase;
    bool hasTime = false;

    void strip(RegExp exp) {
      rest = rest.replaceAll(exp, ' ');
      rest = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    DateTime? nextWeekday(DateTime from, int weekday) {
      var d = DateTime(from.year, from.month, from.day);
      for (var i = 0; i < 7; i++) {
        if (d.weekday == weekday) return d;
        d = d.add(const Duration(days: 1));
      }
      return null;
    }

    final md = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일').firstMatch(rest);
    if (md != null) {
      final month = int.tryParse(md.group(1)!);
      final day = int.tryParse(md.group(2)!);
      if (month != null && day != null) {
        var y = baseNow.year;
        var candidate = DateTime(y, month, day);
        if (candidate.isBefore(
          DateTime(baseNow.year, baseNow.month, baseNow.day),
        )) {
          candidate = DateTime(y + 1, month, day);
        }
        date = candidate;
      }
      strip(RegExp(RegExp.escape(md.group(0)!)));
    }

    if (date == null) {
      final slash = RegExp(r'\b(\d{1,2})/(\d{1,2})\b').firstMatch(rest);
      if (slash != null) {
        final month = int.tryParse(slash.group(1)!);
        final day = int.tryParse(slash.group(2)!);
        if (month != null && day != null) {
          var y = baseNow.year;
          var candidate = DateTime(y, month, day);
          if (candidate.isBefore(
            DateTime(baseNow.year, baseNow.month, baseNow.day),
          )) {
            candidate = DateTime(y + 1, month, day);
          }
          date = candidate;
        }
        strip(RegExp(RegExp.escape(slash.group(0)!)));
      }
    }

    if (date == null) {
      final lower = rest.toLowerCase();
      if (lower.contains('tomorrow') || rest.contains('내일')) {
        date = DateTime(
          baseNow.year,
          baseNow.month,
          baseNow.day,
        ).add(const Duration(days: 1));
        strip(RegExp(r'(tomorrow|내일)', caseSensitive: false));
      } else if (lower.contains('today') || rest.contains('오늘')) {
        date = DateTime(baseNow.year, baseNow.month, baseNow.day);
        strip(RegExp(r'(today|오늘)', caseSensitive: false));
      } else if (rest.contains('모레')) {
        date = DateTime(
          baseNow.year,
          baseNow.month,
          baseNow.day,
        ).add(const Duration(days: 2));
        strip(RegExp(r'모레'));
      }
    }

    if (date == null) {
      final weekdayMap = {
        '월': DateTime.monday,
        '화': DateTime.tuesday,
        '수': DateTime.wednesday,
        '목': DateTime.thursday,
        '금': DateTime.friday,
        '토': DateTime.saturday,
        '일': DateTime.sunday,
      };

      for (final entry in weekdayMap.entries) {
        final exp = RegExp('${entry.key}요일');
        final m = exp.firstMatch(rest);
        if (m != null) {
          date = nextWeekday(baseNow, entry.value);
          strip(exp);
          break;
        }
      }
    }

    final ampm = RegExp(
      r'(오전|오후|am|pm)\s*(\d{1,2})(?::(\d{1,2}))?\s*(시)?',
      caseSensitive: false,
    ).firstMatch(rest);
    if (ampm != null) {
      var hour = int.tryParse(ampm.group(2) ?? '') ?? 0;
      final minute = int.tryParse(ampm.group(3) ?? '') ?? 0;
      final marker = (ampm.group(1) ?? '').toLowerCase();

      if (marker == 'pm' || marker == '오후') {
        if (hour < 12) hour += 12;
      }
      if (marker == 'am' || marker == '오전') {
        if (hour == 12) hour = 0;
      }

      hasTime = true;
      final d = date ?? DateTime(baseNow.year, baseNow.month, baseNow.day);
      timeBase = DateTime(d.year, d.month, d.day, hour, minute);
      strip(RegExp(RegExp.escape(ampm.group(0)!)));
    }

    if (!hasTime) {
      final hm = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(rest);
      if (hm != null) {
        final hour = int.tryParse(hm.group(1) ?? '') ?? 0;
        final minute = int.tryParse(hm.group(2) ?? '') ?? 0;
        hasTime = true;
        final d = date ?? DateTime(baseNow.year, baseNow.month, baseNow.day);
        timeBase = DateTime(d.year, d.month, d.day, hour, minute);
        strip(RegExp(RegExp.escape(hm.group(0)!)));
      }
    }

    if (!hasTime) {
      final h = RegExp(r'\b(\d{1,2})\s*시\b').firstMatch(rest);
      if (h != null) {
        final hour = int.tryParse(h.group(1) ?? '') ?? 0;
        hasTime = true;
        final d = date ?? DateTime(baseNow.year, baseNow.month, baseNow.day);
        timeBase = DateTime(d.year, d.month, d.day, hour, 0);
        strip(RegExp(RegExp.escape(h.group(0)!)));
      }
    }

    if (date == null && !hasTime) {
      return QuickCaptureParseResult(
        title: input.trim(),
        dueAt: null,
        remindAt: null,
        parsed: false,
      );
    }

    DateTime? dueAt;
    if (hasTime && timeBase != null) {
      dueAt = timeBase;
    } else if (date != null) {
      dueAt = DateTime(date.year, date.month, date.day, 23, 59);
    }

    DateTime? remindAt;
    if (dueAt != null && hasTime) {
      final candidate = dueAt.subtract(const Duration(minutes: 30));
      if (candidate.isAfter(baseNow)) {
        remindAt = candidate;
      }
    }

    final cleaned = rest.replaceAll(RegExp(r'\s+'), ' ').trim();

    return QuickCaptureParseResult(
      title: cleaned.isEmpty ? input.trim() : cleaned,
      dueAt: dueAt,
      remindAt: remindAt,
      parsed: true,
    );
  }
}
