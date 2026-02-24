# CampusMate

CampusMate is a local-first planner for university students.
It combines Todo, Calendar, Timetable, and Course PDF notes in one app.

## Live Links

- Website: https://minwoo-khu.github.io/Campusmate/
- Google Play: https://play.google.com/store/apps/details?id=com.campusmate

## Key Features

- Home dashboard: today summary, tip, and study status
- Todo: quick input, due date, reminder, repeat, priority, filters
- Calendar: monthly view with Todo + ICS events
- Timetable: image upload with zoom/pan view
- Courses: per-course PDF management, notes, page memos, tags, memo search
- Settings: theme presets, Korean/English, backup export/restore, backup PIN

## Repository Layout

- `packages/campusmate_core`: shared app logic/UI/data layer
- `apps/mobile`: Android/iOS launcher app
- `apps/desktop_app`: Windows/macOS/Linux launcher app
- `apps/web_app`: Flutter web launcher app
- `services/website`: static landing page (GitHub Pages)

## Quick Start

- Mobile
  - `cd apps/mobile`
  - `flutter run`
- Desktop (Windows)
  - `cd apps/desktop_app`
  - `flutter run -d windows`
- Web app (Flutter)
  - `cd apps/web_app`
  - `flutter run -d chrome`
- Website (static)
  - Open `services/website/index.html`

## Release Output Paths

- Android AAB: `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
- Windows EXE: `apps/desktop_app/build/windows/x64/runner/Release/desktop_app.exe`
- Web build: `apps/web_app/build/web`

## Release Docs

- Store listing draft: `docs/store_listing_ko.md`
- Play release checklist: `docs/play_store_release_checklist.md`
- Data safety draft: `docs/data_safety_draft_ko.md`
- Privacy policy: `docs/privacy_policy_ko.md`, `docs/privacy_policy_en.md`
- Android signing: `docs/android_release_signing_ko.md`

## Current Status

- Home widgets are temporarily disabled for UX refresh.
- Detailed backlog: `docs_feature_proposals.md`
