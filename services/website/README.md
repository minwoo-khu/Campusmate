# CampusMate Website

`services/website`는 CampusMate 랜딩 페이지(정적 사이트)입니다.

## 로컬 확인

간단히 파일 열기:

- `index.html` 더블클릭

또는 정적 서버:

```powershell
cd services/website
python -m http.server 5173
```

접속:

- `http://localhost:5173`

## GitHub Pages 배포

- 워크플로우: `.github/workflows/deploy-website.yml`
- 트리거:
  - `main` 브랜치에 `services/website/**` 변경 푸시
  - 수동 실행(`workflow_dispatch`)

저장소 설정:

- `Settings > Pages > Source = GitHub Actions`

기본 주소:

- `https://minwoo-khu.github.io/Campusmate/`

## Download asset

- Windows direct download file:
  - `services/website/assets/downloads/CampusMate-Windows.zip`
