# CampusMate Desktop App

Desktop launcher app for CampusMate.
Shared app code is in `../../packages/campusmate_core`.

## Run

```powershell
flutter run -d windows
```

## Release Build (Windows)

```powershell
flutter build windows --release
```

Output:

- `build/windows/x64/runner/Release/desktop_app.exe`

## Install Like a Normal App (No Folder Copy)

Run installer script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_desktop_app.ps1
```

Installed path:

- `%LOCALAPPDATA%\Programs\CampusMate\CampusMate.exe`

Shortcuts:

- Start menu: `CampusMate`
- Desktop: `CampusMate` (created by default)
