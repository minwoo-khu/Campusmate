# Merge Conflict Resolution (CalendarScreen / TodoScreen)

아래는 네가 올린 conflict 마커 기준으로 **바로 적용 가능한 최종 선택안**이야.

기준:
- 최근 디자인 리파인(카드/tonal 버튼/여백) 유지
- 기존 기능(ICS sync 메시지, 리트라이, Todo 필터/하이라이트) 유지

---

## 1) `apps/mobile/lib/features/calendar/calendar_screen.dart`

### 선택할 쪽
- `padding`: `EdgeInsets.fromLTRB(16, 8, 16, 0)`
- 헤더 버튼: `IconButton.filledTonal`
- sync 상태 영역: `Card + Row`
- 캘린더: `Card`로 감싼 `TableCalendar`
- selected list: `ListView.builder` + 각 항목 `Card`

### 정리된 블록(붙여넣기)
```dart
body: RefreshIndicator(
  onRefresh: _loadIcs,
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Calendar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: _openIcsSettings,
              icon: const Icon(Icons.link),
              tooltip: 'School calendar (ICS)',
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _loadIcs,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),

        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.sync, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _lastIcsSyncAt == null
                        ? 'School calendar not synced yet'
                        : 'Last sync: ${_fmtSyncLabel(_lastIcsSyncAt!)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
```

---

## 2) `apps/mobile/lib/features/todo/todo_screen.dart`

### 선택할 쪽
- 필터 영역: `SingleChildScrollView + Row`
- 리스트: `padding: EdgeInsets.fromLTRB(16, 4, 16, 120)`
- 아이템: `Padding -> Dismissible -> Card -> ListTile`
- 삭제 배경: `borderRadius: 20` 유지

### 정리된 블록(붙여넣기)
```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          label: Text('전체 ${allItems.length}'),
          selected: _filter == _TodoViewFilter.all,
          onSelected: (_) => setState(() => _filter = _TodoViewFilter.all),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text('진행 ${allItems.where((t) => !t.completed).length}'),
          selected: _filter == _TodoViewFilter.active,
          onSelected: (_) => setState(() => _filter = _TodoViewFilter.active),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text('완료 ${allItems.where((t) => t.completed).length}'),
          selected: _filter == _TodoViewFilter.completed,
          onSelected: (_) => setState(() => _filter = _TodoViewFilter.completed),
        ),
      ],
    ),
  ),
),
```

---

## 3) 로컬에서 conflict 한 번에 정리하는 명령

```bash
git checkout main
git pull origin main

# 충돌난 상태라면
git status
# 각 파일 열어서 위 선택안으로 마커 제거 후

git add apps/mobile/lib/features/calendar/calendar_screen.dart
git add apps/mobile/lib/features/todo/todo_screen.dart
git commit -m "Resolve merge conflicts in calendar/todo UI"
```

> `git checkout --ours` / `--theirs`를 파일 단위로 먼저 적용하고, 그 다음 세부 수정하면 더 빠름.

