# CampusMate

CampusMate는 대학생을 위한 로컬 중심(Local-first) 플래너입니다.  
할 일, 캘린더, 시간표, 강의 PDF/메모를 한 앱에서 관리합니다.

## 저장소 구조

- `packages/campusmate_core`: 공통 앱 로직/UI/데이터 레이어
- `apps/mobile`: Android/iOS 런처 앱 (Play Store 배포 대상)
- `apps/desktop_app`: Windows/macOS/Linux 런처 앱
- `apps/web_app`: Flutter 웹 런처 앱
- `services/website`: 정적 랜딩 페이지 (GitHub Pages 배포)

## 현재 기능 (v1.0.15+16)

- 홈
  - 오늘 요약 (진행 중 / 오늘 마감 / 기한 지남)
  - 오늘 팁
  - 학습 현황 요약
- 할 일
  - 빠른 입력
  - 마감일/리마인더/반복/우선순위
  - 진행/완료 필터
- 캘린더
  - 월간 보기 및 스와이프 이동
  - 할 일 + 학교 ICS 일정 통합 표시
- 시간표
  - 이미지 업로드, 확대/축소 확인
- 강의/자료
  - 강의별 태그/메모
  - PDF 업로드/조회/삭제
  - 전체 메모 + 페이지 메모/태그 + 메모 검색/수정/삭제
- 설정/데이터
  - 테마 프리셋/모드
  - 한국어/영어 전환
  - 백업 내보내기/복원(JSON)
  - 백업 PIN 암호화(선택)

## 데이터/네트워크 원칙

- 사용자 데이터는 기본적으로 기기에 저장됩니다.
- 네트워크 사용은 필요한 경우에 한정됩니다.
  - 사용자가 입력한 ICS URL 조회
  - 광고 SDK 초기화/호출(설정 시)

## 빠른 실행

- Mobile
  - `cd apps/mobile`
  - `flutter run`
- Desktop (Windows)
  - `cd apps/desktop_app`
  - `flutter run -d windows`
- Web App (Flutter)
  - `cd apps/web_app`
  - `flutter run -d chrome`
- Website (정적 랜딩)
  - `services/website/index.html` 직접 열기 또는 정적 서버로 서빙

## 출시 문서

- 스토어 등록 정보: `docs/store_listing_ko.md`
- 출시 체크리스트: `docs/play_store_release_checklist.md`
- Data safety 초안: `docs/data_safety_draft_ko.md`
- 개인정보처리방침: `docs/privacy_policy_ko.md`, `docs/privacy_policy_en.md`
- Android 서명 가이드: `docs/android_release_signing_ko.md`

## 현재 상태

- 홈 위젯 기능은 UX 재정비를 위해 임시 비활성화 상태입니다.

## 로드맵

- 상세 백로그: `docs_feature_proposals.md`
