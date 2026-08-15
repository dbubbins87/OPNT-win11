# Technical notes

## Supported originals

### Operation Neptune 32-bit executable

- Filename: `ONWIN32.EXE`
- SHA-256: `51a4e08aec454d46a4b9cc2bd3e14703cc9592d3ba82cad71c16f308af7ad0cc`
- Format: 32-bit PE/Win32

The original CD also contains the Win16 `ONWINCD.EXE`. This patch intentionally targets the supplied Win32 port rather than introducing a Win16 emulator.

### WinG runtime

- Installed filename: `WING32.DLL`
- Installed SHA-256: `bb1f552e2525e784b61d2fe0ca23f3402adec05aa5f92f4c1dfbea3966a84cbb`
- Tested Microsoft-compressed filename: `WING32.DL_`
- Tested compressed SHA-256: `229ca9629268b9b531efff4fa48961638fc2b104287aad13b4294391e517da80`

Neither form is distributed by this project. When the compressed form is supplied, the patcher invokes Windows `expand.exe` and then verifies the expanded DLL against the installed-DLL hash before applying the WinG patch.

## Patch 1: obsolete color-depth gate

`ONWIN32.EXE` refuses to start when the desktop does not report the 8-bit/paletted configuration expected by the 1990s WinG code path.

- File offset: `0x4C98`
- Virtual address: `0x00414498`
- Original bytes: `6A 0E 53 E8 A7`
- Replacement: `E9 71 00 00 00`

The replacement jumps to the executable's existing cleanup path after the legacy color-depth test.

## Patch 2: portable WinG

The supported `WING32.DLL` contains an installation verifier that compares its own directory to the Windows system directory. If they differ, it displays the "WinG Installation Error" dialog and refuses initialization.

- File offset: `0x9D4`
- Virtual address: `0x200015D4`
- Original bytes: `81 EC A8 04 00 00`
- Replacement: `B8 01 00 00 00 C3`

This makes only the location verifier report success; normal WinG initialization follows.

Patched WinG SHA-256:

`6577fe14fea4f5626c70223b8c6ea3ce529a1b37586c9e1ec2e67f5f6cb7f6c5`

## Patch 3: tested 2× integer scaler

Operation Neptune renders to a fixed 640×400 logical game surface and centers it at 1:1 pixels in a screen-sized window. The executable already loads both `WinGBitBlt` and `WinGStretchBlt`, but normally uses only `WinGBitBlt` for final presentation.

The patch adds a small original x86 code section named `W9XSCL` and redirects the final presentation call through it. The shim calls the game's already-loaded `WinGStretchBlt` pointer to render the 640×400 surface as 1280×800.

It also hooks the beginning of the game window procedure for mouse messages `WM_MOUSEMOVE` through `WM_RBUTTONUP`, translating physical 2× coordinates back to the game's original logical coordinates.

Scaler source: [`../src/opnep_2x_scaler.s`](../src/opnep_2x_scaler.s)

Scaler blob: [`../patches/opnep_2x_scaler.bin`](../patches/opnep_2x_scaler.bin)

### Presentation hook

- VA: `0x00411B37`
- File offset: `0x2337`
- Original: `FF 15 44 6C 44 00`
- Replacement: relative `CALL` to the new section plus `NOP`

### Mouse hook

- VA: `0x0041306F`
- File offset: `0x386F`
- Original: `55 8B EC 83 C4 84`
- Replacement: relative `JMP` to the mouse trampoline plus `NOP`

The tested patched executable SHA-256 is:

`d2bd4e0101b09c88a6c93fa9edc4899d9b1a9a7103db10277db27eb2282f81ea`

## Generated configuration

The patcher creates this file rather than redistributing one:

```ini
[ONWINCD]
CDDrive=.\
CheckDisplay=FALSE
CheckSound=TRUE
```

This lets the copied CD resources live alongside the executable and disables the original display warning that is no longer meaningful on modern Windows.

## Safety model

The patcher:

1. hashes the original executable and WinG source; if WinG is supplied as `WING32.DL_`, expands it and verifies the resulting DLL;
2. verifies expected bytes at each patch location;
3. creates a new destination folder;
4. copies user-supplied original resources;
5. patches only the copies;
6. hashes the finished executable and DLL against the known tested outputs.

If any verification fails, the patch process stops rather than applying offsets to an unknown build.
