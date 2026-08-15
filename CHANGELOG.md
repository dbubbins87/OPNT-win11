# Changelog

## 1.0.1 - 2026-08-15

- Accepts either original `WING32.DLL` or Microsoft-compressed `WING32.DL_`.
- Automatically expands `WING32.DL_` with Windows `expand.exe` and verifies the expanded DLL before patching.
- Auto-detects the tested compressed WinG build by SHA-256.
- Detects `WING.Z` on original media and gives a more accurate explanation instead of implying a loose DLL must be present.
- Corrects the README's WinG-source instructions.

## 1.0.0 - 2026-08-14

Initial public patcher release.

- Supports the known original 32-bit `ONWIN32.EXE` build by SHA-256.
- Bypasses the obsolete 8-bit/256-color startup gate.
- Patches the supported original WinG runtime for local loading.
- Adds the tested 2× integer presentation scaler (640×400 → 1280×800).
- Adds inverse mouse-coordinate mapping for the scaled viewport.
- Builds a fresh portable game folder from user-supplied original files.
- Refuses unknown executable and WinG builds.
- Does not include or download copyrighted game/runtime files.
