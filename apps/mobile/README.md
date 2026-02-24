# CampusMate Mobile

`apps/mobile`은 CampusMate의 모바일 런처(Android/iOS)입니다.  
공통 기능 코드는 `../../packages/campusmate_core`를 사용합니다.

## 로컬 실행

```powershell
flutter run
```

## 릴리즈 빌드 (AAB)

1. `android/key.properties.example`를 복사해 `android/key.properties` 생성
2. keystore 정보 입력
3. 빌드 실행

```powershell
flutter build appbundle --release
```

출력 파일:

- `build/app/outputs/bundle/release/app-release.aab`

## 광고(AdMob)

- Android에서만 동작
- 단위 ID를 지정하지 않으면 테스트 배너 ID를 사용

`android/local.properties` 예시:

```properties
ADMOB_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
```

실제 배너 ID로 실행 예시:

```powershell
flutter run --dart-define=ADMOB_BANNER_UNIT_ID_ANDROID=ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz
```

## 사전 검증 명령

```powershell
flutter analyze
flutter test
flutter build appbundle --release
```

## 관련 문서

- `../../docs/play_store_release_checklist.md`
- `../../docs/android_release_signing_ko.md`
- `../../docs/data_safety_draft_ko.md`
- `../../docs/privacy_policy_ko.md`
- `../../docs/privacy_policy_en.md`
