# CampusMate Desktop

`apps/desktop_app`은 CampusMate의 데스크톱 런처입니다.  
공통 기능 코드는 `../../packages/campusmate_core`를 사용합니다.

## 로컬 실행 (Windows)

```powershell
flutter run -d windows
```

## 릴리즈 빌드 (Windows)

```powershell
flutter build windows --release
```

출력 파일:

- `build/windows/x64/runner/Release/CampusMate.exe`

웹 다운로드용 zip 생성:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_website_windows_zip.ps1
```

## 설치형 배포 (폴더 통복사 없이 실행)

아래 스크립트가 `%LOCALAPPDATA%\Programs\CampusMate`에 설치하고  
시작 메뉴/바탕화면 바로가기를 생성합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_desktop_app.ps1
```

설치 후 실행:

- `%LOCALAPPDATA%\Programs\CampusMate\CampusMate.exe`

제거:

- `%LOCALAPPDATA%\Programs\CampusMate\uninstall.ps1`
