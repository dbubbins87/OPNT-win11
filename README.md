# Operation Neptune Windows 11 Compatibility Patch

An unofficial, bring-your-own-files compatibility patch for the Windows version of **Operation Neptune**.

This repository contains **no Operation Neptune game files** and no copy of Microsoft's original `WING32.DLL`. You must supply files from your own original copy/install.

## What it fixes

Version 1.0.1 applies the set of fixes tested against the supported 32-bit build:

- bypasses the obsolete 8-bit / 256-color startup requirement;
- makes the original WinG runtime usable as a local DLL instead of requiring installation in the Windows system directory;
- scales the original 640×400 game surface to 1280×800 using a tested 2× integer scaler;
- remaps mouse coordinates to the original 640×400 logical viewport;
- keeps the original gameplay, audio, timing, keyboard behavior, resources, and save format intact.

The patch does **not** emulate Windows 3.x. The original disc includes a full 32-bit `ONWIN32.EXE`, which this project patches for modern Windows.

## Requirements

- Windows 11 or a comparable modern 64-bit Windows installation;
- the supported original `ONWIN32.EXE` and its original `NEP*.DLL`/`SOUNDS` data;
- the supported original `WING32.DLL`, **or** Microsoft's compressed `WING32.DL_` form, from an original WinG installation/package.

Supported hashes are documented in [`docs/TECHNICAL.md`](docs/TECHNICAL.md). Unknown builds are rejected instead of being patched blindly.

## Quick start

1. Download the release ZIP and extract it somewhere temporary.
2. Double-click `NeptunePatch.cmd`.
3. Select your original Operation Neptune CD/extracted-CD folder (or another folder containing the original `ONWIN32.EXE`).
4. If the patcher cannot find WinG under that folder, select either the original `WING32.DLL` or its Microsoft-compressed `WING32.DL_` form when prompted. `WING32.DL_` is expanded automatically with Windows `expand.exe`.
5. Choose where the new patched installation should be created.
6. Run `Play Operation Neptune.cmd` from the generated game folder.

The patcher **never modifies the source copy**. It creates a new installation from your original files and applies the compatibility changes only to the copies.

### Command-line use

```powershell
.\NeptunePatch.ps1 `
  -Source "D:\" `
  -Wing32 "C:\OldWinG\WING32.DL_" `
  -Destination "C:\Games\Operation Neptune"
```

`-Wing32` can be omitted if a matching `WING32.DLL` or tested `WING32.DL_` exists somewhere under `-Source`.

## Where do I get WinG?

Modern Windows does not normally contain this old WinG runtime. The patcher accepts either:

- `WING32.DLL` — the installed 32-bit WinG runtime; or
- `WING32.DL_` — Microsoft's old SZDD-compressed form of that DLL.

If you provide `WING32.DL_`, the patcher uses Windows' built-in `expand.exe`, then verifies that the expanded DLL matches the supported SHA-256 before patching it.

The Operation Neptune CD used during development contains a `WING.Z` WinG installer archive, not a loose `WING32.DLL`. Version 1.0.1 detects `WING.Z` and explains this, but does not yet unpack the InstallShield `.Z` archive automatically. You can instead supply `WING32.DLL`/`WING32.DL_` from your own original WinG installation or extracted WinG package.

Do not download random copies from DLL aggregation sites; unknown WinG builds are rejected anyway.

## Why a patcher instead of a prepatched game?

The release contains only original compatibility code, patch metadata, and documentation. The user supplies all copyrighted game/runtime files. The patcher verifies known SHA-256 hashes before changing anything and refuses unexpected versions.

## Supported build

The initial release supports the specific 32-bit Operation Neptune build used during development. If you own a different legitimate release and the patcher rejects it, please open an issue with:

- the filename;
- file size;
- SHA-256 hash;
- release/edition information you know.

Do **not** upload the copyrighted executable or game data to an issue.

## Project scope

The goal is compatibility, not gameplay modification. The patch aims to reproduce the original game behavior on a modern Windows desktop while keeping the original data and logic intact.

## License and rights

The compatibility patcher and original scaler code in this repository are released under the MIT License. That license applies only to code authored for this project.

**Operation Neptune**, its original executables, graphics, audio, data, and related intellectual property belong to their respective rights holders. `WING32.DLL` is third-party Microsoft software and is not included. This project is unofficial and unaffiliated with The Learning Company, Microsoft, or their successors.
