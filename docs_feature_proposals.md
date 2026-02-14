# CampusMate Feature Proposals (Local-first)

This backlog is focused on **free Play Store release** constraints:
- no mandatory backend
- low operating cost
- strong privacy by default

## Priority A (high impact, low complexity)
1. Quick Capture for Todo
   - Add a persistent "+" FAB/input on Todo tab for one-line fast add.
   - Optional smart defaults: due date = today, reminder = off.

2. Overdue / Today sections in Todo
   - Group list into `Overdue`, `Today`, `Upcoming`, `No due date`.
   - Helps students triage work at a glance.

3. Calendar event detail bottom sheet
   - Tap an event to see source (Todo/ICS), exact time, and actions (open/edit).

4. ICS sync reliability UX
   - Per-feed last success/last failure timestamp.
   - Manual refresh icon + lightweight “syncing...” indicator.

## Priority B (retention + usability)
1. Course dashboard cards
   - For each course: upcoming tasks count, last note date, latest material title.

2. PDF note quality-of-life
   - “Recent highlights/notes” list for current document.
   - Jump-to-page from note list.

3. Timetable usability
   - Crop/rotate timetable image in-app.
   - Optional dark overlay slider for readability.

4. Backup / restore (device-local)
   - Export Hive data to a JSON file and import it later.
   - Keeps local-first model while reducing data-loss fear.

## Priority C (polish)
1. Language consistency pass
   - unify UI copy into one default language first.

2. Empty-state UX
   - Add contextual CTA buttons (e.g., “Add first Todo”, “Connect ICS feed”).

3. Theme polishing
   - Harmonize chip/button color tokens and spacing scale.

## Suggested next sprint (1 week)
- Day 1-2: Todo `Overdue/Today/Upcoming` grouping + quick add
- Day 3: Calendar event detail sheet
- Day 4: Course dashboard card summary
- Day 5: Buffer + bug fixes

## Deferred (requested for later)
- ICS user guidance notice
  - Add a one-time in-app notice/banner explaining how to connect school calendar via ICS.
  - Explain where to get the school ICS URL and that only HTTPS ICS URLs are supported.
  - Add a reopenable help entry in Settings (e.g., "How to connect ICS").
