# CampusMate Desktop App

Desktop launcher app for CampusMate.
Shared app code is in `../../packages/campusmate_core`.

## Run

```powershell
flutter run -d windows
```

## Release Build (Windows)

`jni` native dependency needs a JDK path containing `include/jni.h`.

```powershell
$env:JAVA_HOME="C:\path\to\jdk"
flutter build windows --release
```

Output:

- `build/windows/x64/runner/Release/desktop_app.exe`
