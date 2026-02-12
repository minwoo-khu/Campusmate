import 'package:flutter/material.dart';

import 'change_history_service.dart';
import 'l10n.dart';
import 'theme.dart';

Future<void> showChangeHistorySheet(BuildContext context) {
  final entries = ChangeHistoryService.recent(limit: 30);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final cm = sheetContext.cmColors;
      String tr(String ko, String en) => sheetContext.tr(ko, en);

      String actionText(String action) {
        switch (action) {
          case 'Todo added':
            return tr('할 일 추가', 'Todo added');
          case 'Todo completed':
            return tr('할 일 완료', 'Todo completed');
          case 'Todo reopened':
            return tr('할 일 다시 진행', 'Todo reopened');
          case 'Recurring todo scheduled':
            return tr('반복 할 일 생성', 'Recurring todo scheduled');
          case 'Todo updated':
            return tr('할 일 수정', 'Todo updated');
          case 'Todo deleted':
            return tr('할 일 삭제', 'Todo deleted');
          case 'Todo restored':
            return tr('할 일 복원', 'Todo restored');
          case 'Course added':
            return tr('강의 추가', 'Course added');
          case 'Course updated':
            return tr('강의 수정', 'Course updated');
          case 'Course deleted':
            return tr('강의 삭제', 'Course deleted');
          case 'Course restored':
            return tr('강의 복원', 'Course restored');
          case 'PDF uploaded':
            return tr('PDF 업로드', 'PDF uploaded');
          case 'PDF deleted':
            return tr('PDF 삭제', 'PDF deleted');
          case 'PDF restored':
            return tr('PDF 복원', 'PDF restored');
          default:
            return action;
        }
      }

      if (entries.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Text(tr('최근 변경 내역이 없습니다.', 'No recent changes yet.')),
        );
      }

      String two(int x) => x.toString().padLeft(2, '0');
      String fmt(DateTime dt) =>
          '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';

      return SizedBox(
        height: 420,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemBuilder: (_, i) {
            final e = entries[i];
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(actionText(e.action)),
              subtitle: e.detail.isEmpty ? null : Text(e.detail),
              trailing: Text(
                fmt(e.at),
                style: TextStyle(fontSize: 12, color: cm.textTertiary),
              ),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: entries.length,
        ),
      );
    },
  );
}
