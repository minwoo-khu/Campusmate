# Android 릴리즈 서명 가이드

최종 업데이트: 2026-02-12

## 1) 업로드 키스토어 생성

Windows PowerShell 예시:

```powershell
keytool -genkeypair -v `
  -keystore upload-keystore.jks `
  -alias upload `
  -keyalg RSA -keysize 2048 -validity 10000
```

생성된 `upload-keystore.jks` 파일은 Git에 올리지 말고 안전한 위치에 백업하세요.

## 2) key.properties 생성

`apps/mobile/android/key.properties.example`를 복사해서
`apps/mobile/android/key.properties` 파일을 만듭니다.

예시:

```properties
storeFile=../keystore/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

## 3) 릴리즈 빌드

```powershell
cd apps/mobile
flutter build appbundle --release
```

성공 시 산출물:
- `apps/mobile/build/app/outputs/bundle/release/app-release.aab`

## 4) 체크 포인트

- `key.properties`/`.jks`는 절대 커밋 금지
- 키스토어 파일 + 비밀번호를 오프라인 백업
- 업로드 키 분실 대비 문서화
