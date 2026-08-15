# Suggested MyAbandonware submission description

**Operation Neptune Windows 11 Compatibility Patch 1.0.1**

Unofficial compatibility patch for the Windows version of Operation Neptune. The download does not contain the game or its original assets and requires files from an original copy.

Fixes included:

- modern Windows color-depth startup compatibility;
- portable/local WinG loading;
- 2× integer scaling of the original 640×400 game viewport to 1280×800;
- corrected mouse coordinates for the scaled viewport.

The patcher verifies the supported original executable and WinG runtime by SHA-256; it accepts either `WING32.DLL` or Microsoft's compressed `WING32.DL_`, copies the original game data to a new folder, and patches only the copies. It does not overwrite the source installation.

The project is unofficial and unaffiliated with the game's rights holders.
