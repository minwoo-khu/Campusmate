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

## Ads (AdMob)

Ads are enabled on Android builds by default.

- Debug builds use Google's test banner unit automatically.
- Release builds require a real banner unit id (`ADMOB_BANNER_UNIT_ID_ANDROID`).

Set AdMob app id in `android/local.properties`:

```properties
ADMOB_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
```

Run with a real banner unit id:

```powershell
flutter run --dart-define=ADMOB_BANNER_UNIT_ID_ANDROID=ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz
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
