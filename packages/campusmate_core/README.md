# campusmate_core

CampusMate의 공통 코어 패키지입니다.

모바일/데스크톱/웹 런처(`apps/*`)가 이 패키지를 사용해 같은 기능과 UI를 공유합니다.

## 포함 범위

- 앱 루트/테마/언어 전환
- 홈/할 일/캘린더/시간표/강의 탭 UI
- Todo/Course/PDF 메모 데이터 모델 및 저장 로직(Hive)
- ICS 연동, 알림, 백업/복원, PIN 암호화

## 설계 원칙

- 로컬 중심 저장(Local-first)
- 계정/서버 의존 최소화
- 플랫폼별 선택 기능은 가드 처리(지원 플랫폼에서만 실행)

## 개발 참고

분석/테스트:

```powershell
flutter analyze
flutter test
```
