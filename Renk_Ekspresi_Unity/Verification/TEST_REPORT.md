# Unity migration verification — 2026-10-23

## Passed

The original v0.34 Godot engine was executed headlessly using Godot 4.5.1. C# was compiled and executed with .NET SDK 8.0.408. The same recorded actions were replayed into the C# engine, using 0.05-second calls subdivided into 0.025-second rule steps.

- 100 campaign solution traces agree with the original engine.
- 16 additional traces cover non-solution selections, full slots, VIP/reward slots, booster refill, freeze, recall and blast. Some end in loss; some win. C# outcomes and intermediate states agree with Godot.
- Across 4,471 snapshots, elapsed time, heads, remaining wagon IDs/distances, slot occupancy and collector capacities were compared. Edge cases also compare booster stock, freeze time, target assignments and ready times.
- Floating distance/time comparison tolerance: 0.00025 world units/seconds. Discrete state comparisons are exact.
- 100 idle runs reach loss.
- Blocked choices are rejected; fresh wagons are not collectible; slot limits/reset work; duplicate/stale reward callbacks cannot grant again; absent SDKs cannot fabricate purchases or rewards.
- Legacy progress and standard/assisted records migrate in an in-memory fixture. Test entitlement flags are ignored.
- Total: **380,199 assertions passed**. Full output: `core-results.txt`.
- `Tools/validate_assets.py`: all 100 campaign/route pairs, 6 meshes, referenced fonts, sound clips, icons and shaders are present and structurally valid.
- 68 Roslyn C# 9 syntax checks passed (0 parsing errors); checks are run for Editor, iOS, Android and WebGL preprocessor configurations. See `syntax-results.txt`.

## Not verified

Unity Editor is not installed in this environment. No Unity player was compiled or run. Unity API binding, Package Manager resolution, asset importer behavior, shader compilation, actual UI layout, touch handling, native haptics, platform builds, IDBFS persistence, native save-directory discovery and FPS/memory remain unverified. Syntax parsing is **not** a Unity compile.

This is a source migration candidate, not a store-ready binary or a validated visual upgrade. No WebGL/IPA/APK/AAB is included. The previous Godot deployment has not been replaced.

## Reproduce

From `Verification`, using .NET SDK 8:

```bash
dotnet run --project Verification.csproj
dotnet run --project SyntaxCheck.csproj
```

From the project root:

```bash
python3 Tools/validate_assets.py
```

The verification project uses Json.NET bundled with the .NET SDK only for the save-migration fixture. Unity obtains Json.NET through its official package. Engine replay itself uses no Unity or Json.NET APIs.

`Tools/export_unity.gd` and `Tools/export_unity_edges.gd` regenerate the reference data when copied into the original v0.34 Godot project's `tests` folder. Pass the Unity project path with `-- --unity-project /absolute/path` after the Godot command. Run `Tools/normalize_json.py` afterward. Keep the original Godot package as the immutable source of truth.
