# CampusMate Mobile

Flutter client for CampusMate.

## Release Build

1. Copy `android/key.properties.example` to `android/key.properties`
2. Fill keystore values (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`)
3. Build release bundle:

```powershell
flutter build appbundle --release
```

## Crash Reporting (Sentry)

Crash reporting is optional and disabled by default.

Enable with dart-defines:

```powershell
flutter run --dart-define=ENABLE_SENTRY=true --dart-define=SENTRY_DSN=<your_dsn>
```

## Pre-release Verification

```powershell
flutter analyze
flutter test
flutter build appbundle --release
```

Related docs:
- `../../docs/play_store_release_checklist.md`
- `../../docs/android_release_signing_ko.md`
- `../../docs/crash_reporting_sentry_ko.md`
- `../../docs/data_safety_draft_ko.md`
- `../../docs/privacy_policy_ko.md`
- `../../docs/privacy_policy_en.md`
