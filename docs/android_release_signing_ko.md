# Android 릴리즈 서명 가이드

기준일: 2026-02-24

## 1) 업로드 키스토어 생성

Windows PowerShell 예시:

```powershell
keytool -genkeypair -v `
  -keystore upload-keystore.jks `
  -alias upload `
  -keyalg RSA -keysize 2048 -validity 10000
```

생성된 `upload-keystore.jks`는 Git에 커밋하지 않고, 안전한 위치에 백업합니다.

## 2) `key.properties` 작성

`apps/mobile/android/key.properties.example`를 복사해  
`apps/mobile/android/key.properties`를 생성합니다.

예시:

```properties
storeFile=../keystore/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

## 3) AAB 빌드

```powershell
cd apps/mobile
flutter build appbundle --release
```

출력 파일:

- `apps/mobile/build/app/outputs/bundle/release/app-release.aab`

## 4) 체크 포인트

- `.jks` / `key.properties`는 절대 저장소에 커밋하지 않기
- 키스토어와 비밀번호는 오프라인 백업 유지
- Play Console 업로드 전에 버전 증가 여부 확인
