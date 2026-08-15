# Operation Neptune Windows 11 Compatibility Patch 1.0.1

This is a bring-your-own-files compatibility patch. It contains only the patcher, original compatibility code, patch data, documentation, and MIT license. **No Operation Neptune files and no Microsoft WinG DLL are included.**

### Fixes

- Windows 11 startup on modern color-depth desktops
- local WinG support without installing it into Windows
- tested 2× integer scaling (640×400 → 1280×800)
- scaled mouse-coordinate correction

### WinG input improvement in 1.0.1

The patcher now accepts either the installed `WING32.DLL` **or** Microsoft's SZDD-compressed `WING32.DL_`.

When `WING32.DL_` is supplied, the patcher:

1. expands it with Windows' built-in `expand.exe`;
2. verifies the SHA-256 of the expanded `WING32.DLL`;
3. patches only the verified temporary copy;
4. removes the temporary expansion directory afterward.

The tested compressed `WING32.DL_` SHA-256 is:

`229ca9629268b9b531efff4fa48961638fc2b104287aad13b4294391e517da80`

The Operation Neptune CD used during development exposes WinG as an InstallShield `WING.Z` archive rather than a loose DLL. The patcher detects `WING.Z` and explains what is needed, but 1.0.1 does not unpack `.Z` archives itself.

### Usage

Extract the release and run `NeptunePatch.cmd`. Provide your original files when prompted.
