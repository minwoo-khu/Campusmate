class IcsEvent {
  final String uid;
  final String summary;
  final DateTime start;
  final DateTime? end;
  final bool allDay;

  IcsEvent({
    required this.uid,
    required this.summary,
    required this.start,
    required this.end,
    required this.allDay,
  });
}

/// 아주 최소한의 VEVENT 파서.
/// - UID, SUMMARY, DTSTART, DTEND(옵션), 종일(YYYYMMDD) 처리
List<IcsEvent> parseIcs(String icsText) {
  final lines = _unfoldLines(icsText);

  final events = <IcsEvent>[];
  bool inEvent = false;

  String uid = '';
  String summary = '';
  String dtStartRaw = '';
  String dtEndRaw = '';

  for (final line in lines) {
    if (line == 'BEGIN:VEVENT') {
      inEvent = true;
      uid = '';
      summary = '';
      dtStartRaw = '';
      dtEndRaw = '';
      continue;
    }
    if (line == 'END:VEVENT') {
      if (inEvent && dtStartRaw.isNotEmpty) {
        final startInfo = _parseDt(dtStartRaw);
        final endInfo = dtEndRaw.isEmpty ? null : _parseDt(dtEndRaw);

        events.add(
          IcsEvent(
            uid: uid.isEmpty ? '${summary}_${dtStartRaw}' : uid,
            summary: summary.isEmpty ? '(No title)' : summary,
            start: startInfo.dateTime,
            end: endInfo?.dateTime,
            allDay: startInfo.allDay,
          ),
        );
      }
      inEvent = false;
      continue;
    }

    if (!inEvent) continue;

    if (line.startsWith('UID:')) uid = line.substring(4).trim();
    if (line.startsWith('SUMMARY:')) summary = line.substring(8).trim();

    if (line.startsWith('DTSTART')) {
      // DTSTART;VALUE=DATE:20260128 같은 경우도 있음
      dtStartRaw = line.split(':').last.trim();
    }
    if (line.startsWith('DTEND')) {
      dtEndRaw = line.split(':').last.trim();
    }
  }

  return events;
}

class _DtInfo {
  final DateTime dateTime;
  final bool allDay;
  _DtInfo(this.dateTime, this.allDay);
}

_DtInfo _parseDt(String raw) {
  // 종일: 20260128
  if (raw.length == 8) {
    final y = int.parse(raw.substring(0, 4));
    final m = int.parse(raw.substring(4, 6));
    final d = int.parse(raw.substring(6, 8));
    return _DtInfo(DateTime(y, m, d), true);
  }

  // 일반: 20260128T090000Z or 20260128T090000
  final hasZ = raw.endsWith('Z');
  final cleaned = hasZ ? raw.substring(0, raw.length - 1) : raw;

  final y = int.parse(cleaned.substring(0, 4));
  final m = int.parse(cleaned.substring(4, 6));
  final d = int.parse(cleaned.substring(6, 8));
  final hh = int.parse(cleaned.substring(9, 11));
  final mm = int.parse(cleaned.substring(11, 13));
  final ss = int.parse(cleaned.substring(13, 15));

  final dt = DateTime(y, m, d, hh, mm, ss);
  // Z면 UTC로 보고 local로 변환
  return _DtInfo(hasZ ? dt.toUtc().toLocal() : dt, false);
}

/// iCal line folding 처리(다음 줄이 공백/탭으로 시작하면 이어붙임)
List<String> _unfoldLines(String text) {
  final raw = text.split(RegExp(r'\r?\n'));
  final out = <String>[];

  for (final l in raw) {
    if (l.isEmpty) continue;
    if ((l.startsWith(' ') || l.startsWith('\t')) && out.isNotEmpty) {
      out[out.length - 1] = out.last + l.substring(1);
    } else {
      out.add(l.trimRight());
    }
  }
  return out;
}
