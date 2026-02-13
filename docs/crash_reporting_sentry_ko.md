# Sentry 크래시 리포팅 설정

최종 업데이트: 2026-02-12

CampusMate는 `sentry_flutter`를 기본 포함하고, 아래 조건에서만 활성화됩니다.

- `--dart-define=ENABLE_SENTRY=true`
- `--dart-define=SENTRY_DSN=...`

## 1) 실행 예시

```powershell
cd apps/mobile
flutter run --dart-define=ENABLE_SENTRY=true --dart-define=SENTRY_DSN=https://<key>@o<org>.ingest.sentry.io/<project>
```

릴리즈 빌드 예시:

```powershell
flutter build appbundle --release `
  --dart-define=ENABLE_SENTRY=true `
  --dart-define=SENTRY_DSN=https://<key>@o<org>.ingest.sentry.io/<project>
```

## 2) 앱 내 점검

설정 > `크래시 리포팅` 섹션에서:
- 상태(활성/비활성) 확인
- 테스트 이벤트 전송 버튼 실행

## 3) 권장 운영

- 프로덕션 DSN은 CI/CD 비밀변수로 관리
- 디버그/스테이징/프로덕션 프로젝트 분리
- 릴리즈 태그와 Sentry release 버전 일치
