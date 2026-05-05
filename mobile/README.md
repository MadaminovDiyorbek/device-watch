# DeviceWatch — mobil (Flutter)

## Flutter SDK (loyiha ichida)

SDK yo‘li: `tools/flutter/` (git `stable`, `.gitignore` da).

Yangilash:

```powershell
cd D:\CM\tools\flutter
git pull
```

## Ishga tushirish

PowerShell:

```powershell
cd D:\CM\mobile
.\bootstrap.ps1
cd .\device_watch_app
D:\CM\flutterw.bat run
```

`flutterw.bat` — loyihadagi `tools\flutter\bin\flutter.bat` ni chaqiradi (ildizdan: `D:\CM\flutterw.bat`).

**Cursor / VS Code:** `.vscode/settings.json` da `dart.flutterSdkPath` loyihadagi SDK ga yo‘naltirilgan.

## Server manzili

- **Android emulyator** → `http://10.0.2.2:5050` (standart `Prefs`)
- **Haqiqiy telefon** → Wi-Fi dagi kompyuter IP, masalan `http://192.168.1.10:5050`

Ilova: server URL, `ENROLLMENT_KEY`, qurilma nomi.

## Android toolchain

`flutter doctor` agar **cmdline-tools** yo‘q desa, Android Studio orqali **SDK Command-line Tools** o‘rnating yoki [commandlinetools](https://developer.android.com/studio#command-line-tools-only).

## HTTP (dev)

Android `usesCleartextTraffic` allaqachon yoqilgan. iOS: `Info.plist` da `NSAppTransportSecurity` / `NSAllowsLocalNetworking`.
