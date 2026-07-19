# Android build guide

## First test preset

The project ships an `Android Debug` APK preset in `export_presets.cfg`:

- output: `Builds/Android/FruitMerge-debug.apk`;
- application id: `com.yuna.fruitmerge`;
- display name: `Fruit Merge`;
- version name/code: `0.1.0` / `1`;
- architecture: ARM64;
- orientation: portrait, inherited from `project.godot`;
- permissions: vibration only; Internet is intentionally disabled until the ad/billing platform integration exists.
- textures: ETC2/ASTC import enabled, as required by Godot's Android exporter.
- launcher icon: the existing smiling peach game asset, replacing Godot's default icon.
- startup: Godot's default boot image/splash disabled; the Android system launch
  screen may still briefly display the peach app icon.

The package id becomes the app's installation identity. Decide the final globally
unique id before the first Play Console upload; changing it later creates a
different Android application and save-data location.

## Tooling

Godot 4.7 on Windows requires OpenJDK 17 and an Android SDK. Configure these in
Editor Settings > Export > Android. The SDK must contain Platform Tools 35.0.0 or
newer, Build Tools 35.0.1, Platform 35, and the latest Command-line Tools. The
official setup reference is the [Godot 4.7 Android export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html).

This workstation is configured with:

- Godot `4.7.1.stable`;
- Temurin OpenJDK `17.0.19` at
  `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`;
- Android SDK at `C:\Users\Yuna\AppData\Local\Android\Sdk`;
- Platform Tools `37.0.0`, Build Tools `35.0.1`, Platform `35`, and current
  Command-line Tools;
- a local standard Android debug keystore in Godot's self-contained
  `editor_data/keystores` directory.

The SDK/JDK paths and debug keystore are editor-machine settings, not repository
files. A new development machine must configure them again.

## Build

Run project validation first, then export:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path . --script res://Tests/run_all.gd

& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path . --export-debug 'Android Debug' `
  'Builds/Android/FruitMerge-debug.apk'
```

The debug APK uses the local debug keystore and is for device testing only. A
Google Play release must use an AAB/Gradle preset plus a private release keystore;
never commit that keystore or its passwords.

Install or update the debug build on a USB-debugging-enabled ARM64 device with:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r `
  'Builds/Android/FruitMerge-debug.apk'
```

If Android reports a signature mismatch, uninstall the older package first. That
removes its local save data, so do this only for a disposable test installation.

## Latest validated debug build

The signed debug APK was rebuilt and validated on 2026-07-19 after the tall-phone
layout pass:

- path: `Builds/Android/FruitMerge-debug.apk`;
- size: `71,433,524` bytes (`68.12 MiB`);
- SHA-256: `AA11B0E89C7FEB7BAFE568155C2E6B7E90510EE03FD9D184EE3C495A74D2859C`;
- manifest: package `com.yuna.fruitmerge`, version `0.1.0` / code `1`, minimum
  SDK `24`, target SDK `36`, portrait activity;
- native ABI: `arm64-v8a` only;
- permissions: `android.permission.VIBRATE` only;
- signing: standard debug RSA certificate, verified with APK Signature Scheme
  v2 and v3;
- layout: 9:20 desktop preview, responsive Home/Shop bottom docks, vertically
  centered mascot art, stretching Shop catalog, touch-scrollable hidden-bar Pets
  grid, and safe-area-aware loading footer;
- validation: fruit chain, catalog, UI contracts, and core scenes passed.

`Builds/` is ignored by Git. The checksum is a record of this exact APK and will
change on later exports. Installation and launch still need to be smoke-tested on
a connected physical Android device before sharing the build with testers.
