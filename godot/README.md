# Sealsworn Godot Project

Production Godot project for Sealsworn.

- Engine: Godot 4.6.3 stable standard build.
- Language: typed GDScript.
- Target: mobile/tablet first, Windows desktop parity.
- Architecture: scene-independent domain model owns gameplay truth; scenes mirror domain outcomes.

Run headless tests after installing Godot:

```powershell
godot --headless --path C:\Sealsworn\godot --scene res://tests/headless/test_runner.tscn --quit-after 10
```

Do not make production code depend on `prototype/`.
