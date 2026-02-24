# CampusMate

CampusMate is a local-first campus planner for university students.
It combines Todo, Calendar, Timetable, and Course materials in one app.

## Workspace Layout

- `packages/campusmate_core`: shared app logic/UI/data layer
- `apps/mobile`: Android/iOS launcher app (Play Store release target)
- `apps/desktop_app`: desktop launcher app (Windows/macOS/Linux)
- `apps/web_app`: web launcher app (static hosting target)

## Current Features (v1.0.15+16)

- Home dashboard
  - Today overview (active / due today / overdue)
  - Today tip
  - Study status summary
- Todo
  - Quick input
  - Due date, reminder, repeat, priority
  - Active/completed filters and grouped list
  - Reminder snooze actions
- Calendar
  - Monthly view with swipe month navigation
  - Todo due dates + School ICS events in one timeline
  - ICS settings screen (HTTPS-only feed URL)
- Timetable
  - Upload timetable image and view with zoom/pan
  - Optional course name recognition from image with selectable import
- Courses and PDF notes
  - Course memo/tags
  - PDF upload/view/delete per course
  - PDF overall note + page memo/tags
  - Page memo search/edit/delete
- Settings and data
  - Theme mode and color preset selection
  - Korean/English language switch
  - Local backup export/restore (JSON)
  - Optional backup PIN encryption

## Local-first & Privacy

- User data is stored on device by default.
- Network access is limited to features that need it:
  - School ICS sync (when user adds an ICS URL)
  - Ads/analytics/crash tooling if enabled in release config

## Known Status

- Home widget feature is temporarily disabled for release stability.
  - It is planned to return after UX/interaction refresh.

## Roadmap

Roadmap/backlog is maintained in `docs_feature_proposals.md`.

Current priority direction:
- Improve timetable OCR block-level recognition quality
- Improve PDF memo anchor UX (viewport-based memo positioning)
- Add better ICS connection guidance in-app
- Re-enable home widgets after UX refresh

## Play Store Docs

- Store listing draft: `docs/store_listing_ko.md`
- Release checklist: `docs/play_store_release_checklist.md`
- Privacy policy drafts: `docs/privacy_policy_ko.md`, `docs/privacy_policy_en.md`

## Quick Start

- Mobile:
  - `cd apps/mobile`
  - `flutter run`
- Desktop:
  - `cd apps/desktop_app`
  - `flutter run -d windows` (requires Visual Studio C++ workload)
  - Windows release builds require `JAVA_HOME` pointing to a JDK that contains `include/jni.h`
- Web:
  - `cd apps/web_app`
  - `flutter run -d chrome`
