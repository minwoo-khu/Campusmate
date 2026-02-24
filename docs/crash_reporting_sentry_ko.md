# 크래시 리포팅 문서 상태

기준일: 2026-02-24

현재 CampusMate는 Sentry를 사용하지 않습니다.

- `sentry_flutter` 의존성 제거됨
- `ENABLE_SENTRY`, `SENTRY_DSN` 설정 사용 안 함
- 크래시 처리 로직은 앱 내부 fallback 훅 기반으로 유지

이 문서는 과거 Sentry 설정 문서의 대체 안내입니다.
