# Flutter Engine Patch for CJK

Place custom-patched Flutter engine binaries here to override the stock engine
in CI builds. This is used to fix CJK font rendering on Raspberry Pi targets
where the official flutter-pi `libflutter_engine.so` lacks proper CJK glyph support.

The custom engine is compiled with `--enable-fontconfig` against **Flutter 3.38.4**
to enable system-level font fallback, which is required for correct CJK text
rendering on Linux/ARM targets where fontconfig is available.

> **Note:** The engine version must match the Flutter SDK used in CI (currently
> `3.38.4` in `build.yml`). Mismatched versions will likely crash at runtime.

## Files

- `libflutter_engine.so` — Custom-patched engine shared library (all arches)
- `icudtl.dat` — ICU data bundle with full CJK character tables

## How it works

The CI workflow (`build.yml`) checks for these files after each `flutterpi_tool build`
step. If found, they are copied into the build output directory before the tarball
is created, replacing the stock engine binaries.

## Architecture notes

If you need different binaries per architecture, name them with an arch suffix:

- `libflutter_engine.armv7.so`
- `libflutter_engine.aarch64.so`
- `libflutter_engine.x64.so`
- `icudtl.armv7.dat`
- `icudtl.aarch64.dat`
- `icudtl.x64.dat`

Otherwise, a plain `libflutter_engine.so` / `icudtl.dat` is applied to all arches.
