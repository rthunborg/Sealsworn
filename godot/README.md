# Sealsworn Godot Project

Production Godot project for Sealsworn.

- Engine: Godot 4.6.3 stable standard build.
- Language: typed GDScript.
- Target: mobile/tablet first, Windows desktop parity.
- Architecture: scene-independent domain model owns gameplay truth; scenes mirror domain outcomes.

## Local Commands

Check the local Godot version:

```powershell
godot --version
```

Expected local setup for this baseline:

```text
4.6.3.stable.official.7d41c59c4
```

Run headless tests after installing Godot:

```powershell
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

Launch the production project on Windows:

```powershell
godot --path C:\Sealsworn\godot
```

Optional explicit boot scene run:

```powershell
godot --path C:\Sealsworn\godot --scene res://scenes/app/boot.tscn
```

## Export Setup

`export_presets.cfg` contains non-secret Windows Desktop MVP and Android MVP scaffolding. Production export filters exclude source-only data, debug scenes, tests, tools, and test scripts:

- `data/source/**`
- `scenes/debug/**`
- `tests/**`
- `tools/**`
- `**/test_*.gd`

Android export is scaffolded but not signed. Before creating local Android builds, install or verify:

- Godot export templates
- Android Studio
- OpenJDK 17
- Android SDK Platform-Tools 35.0.0 or later
- Android SDK Build-Tools 35.0.1
- Android SDK Platform 35
- Latest Android SDK command-line tools
- CMake 3.10.2.4988404
- NDK r28b

Next action for Android builds: install the prerequisites above, configure local Godot editor export paths, then create unsigned local debug exports from the existing Android MVP preset. Do not add signing secrets, account-specific values, cloud services, telemetry services, multiplayer services, or prototype dependencies.

iOS export is deferred in this Windows workspace and does not block the headless test harness or Epic 1 domain implementation. iOS export requires Godot export templates, macOS with Xcode, and local platform signing setup. Keep iOS signing values, team identifiers, and account-specific fields blank or placeholder-only in tracked files; do not commit signing secrets.

Do not make production code depend on `prototype/`.
