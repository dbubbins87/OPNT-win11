[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Source,

    [Parameter(Mandatory=$false)]
    [string]$Wing32,

    [Parameter(Mandatory=$false)]
    [string]$Destination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PatchVersion = '1.0.1'
$KnownExeSha256 = '51a4e08aec454d46a4b9cc2bd3e14703cc9592d3ba82cad71c16f308af7ad0cc'
$KnownWingSha256 = 'bb1f552e2525e784b61d2fe0ca23f3402adec05aa5f92f4c1dfbea3966a84cbb'
$KnownWingCompressedSha256 = '229ca9629268b9b531efff4fa48961638fc2b104287aad13b4294391e517da80'
$ExpectedPatchedExeSha256 = 'd2bd4e0101b09c88a6c93fa9edc4899d9b1a9a7103db10277db27eb2282f81ea'
$ExpectedPatchedWingSha256 = '6577fe14fea4f5626c70223b8c6ea3ce529a1b37586c9e1ec2e67f5f6cb7f6c5'

function Write-Status([string]$Text) {
    Write-Host ('[NeptunePatch] ' + $Text)
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Select-Folder([string]$Description) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Operation cancelled.'
    }
    return $dialog.SelectedPath
}

function Select-File([string]$Title, [string]$Filter) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = $Filter
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Operation cancelled.'
    }
    return $dialog.FileName
}

function Find-FileByHash([string]$Root, [string]$Name, [string]$Sha256) {
    $items = @(Get-ChildItem -LiteralPath $Root -Filter $Name -File -Recurse -ErrorAction SilentlyContinue)
    foreach ($item in $items) {
        try {
            if ((Get-Sha256 $item.FullName) -eq $Sha256) {
                return $item.FullName
            }
        } catch {
            # Ignore unreadable candidates and continue searching.
        }
    }
    return $null
}

function Resolve-WinGSource([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "WinG source file not found: $full"
    }

    $name = [System.IO.Path]::GetFileName($full)
    if ($name.Equals('WING32.DLL', [System.StringComparison]::OrdinalIgnoreCase)) {
        $sha = Get-Sha256 $full
        if ($sha -ne $KnownWingSha256) {
            throw "That WING32.DLL is not the supported original build. SHA-256: $sha"
        }
        return [PSCustomObject]@{
            Path = $full
            TempDir = $null
            SourceKind = 'WING32.DLL'
        }
    }

    if ($name.Equals('WING32.DL_', [System.StringComparison]::OrdinalIgnoreCase)) {
        $compressedSha = Get-Sha256 $full
        if ($compressedSha -eq $KnownWingCompressedSha256) {
            Write-Status 'Recognized the tested Microsoft SZDD-compressed WING32.DL_ build.'
        } else {
            Write-Status "WING32.DL_ compressed hash is not the tested package ($compressedSha); it will be accepted only if it expands to the supported WING32.DLL."
        }

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('NeptunePatch-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        $expanded = Join-Path $tempDir 'WING32.DLL'

        try {
            $expandExe = $null
            if (-not [string]::IsNullOrWhiteSpace($env:SystemRoot)) {
                $candidate = Join-Path $env:SystemRoot 'System32\expand.exe'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $expandExe = $candidate
                }
            }
            if ($null -eq $expandExe) {
                $cmd = Get-Command 'expand.exe' -ErrorAction SilentlyContinue
                if ($null -ne $cmd) {
                    $expandExe = $cmd.Source
                }
            }
            if ($null -eq $expandExe) {
                throw 'Windows expand.exe could not be located.'
            }

            Write-Status "Expanding WING32.DL_ with $expandExe..."
            & $expandExe $full $expanded | Out-Null
            $code = $LASTEXITCODE
            if (($code -ne 0) -or (-not (Test-Path -LiteralPath $expanded -PathType Leaf))) {
                throw "expand.exe failed while expanding WING32.DL_ (exit code $code)."
            }

            $expandedSha = Get-Sha256 $expanded
            if ($expandedSha -ne $KnownWingSha256) {
                throw "Expanded WING32.DLL is not the supported build. SHA-256: $expandedSha"
            }

            return [PSCustomObject]@{
                Path = $expanded
                TempDir = $tempDir
                SourceKind = 'WING32.DL_'
            }
        }
        catch {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            throw
        }
    }

    throw "Select WING32.DLL or its Microsoft-compressed WING32.DL_ form, not '$name'."
}

function Assert-Bytes([byte[]]$Bytes, [int]$Offset, [byte[]]$Expected, [string]$Label) {
    if (($Offset -lt 0) -or (($Offset + $Expected.Length) -gt $Bytes.Length)) {
        throw "${Label}: patch offset is outside the file."
    }
    for ($i = 0; $i -lt $Expected.Length; $i++) {
        if ($Bytes[$Offset + $i] -ne $Expected[$i]) {
            $actual = ($Bytes[$Offset..($Offset + $Expected.Length - 1)] | ForEach-Object { $_.ToString('X2') }) -join ' '
            $wanted = ($Expected | ForEach-Object { $_.ToString('X2') }) -join ' '
            throw "${Label}: expected bytes '$wanted' at 0x$($Offset.ToString('X')), found '$actual'."
        }
    }
}

function Put-Bytes([byte[]]$Bytes, [int]$Offset, [byte[]]$Value) {
    [Array]::Copy($Value, 0, $Bytes, $Offset, $Value.Length)
}

function Read-U16([byte[]]$Bytes, [int]$Offset) {
    return [BitConverter]::ToUInt16($Bytes, $Offset)
}

function Read-U32([byte[]]$Bytes, [int]$Offset) {
    return [BitConverter]::ToUInt32($Bytes, $Offset)
}

function Write-U16([byte[]]$Bytes, [int]$Offset, [UInt16]$Value) {
    Put-Bytes $Bytes $Offset ([BitConverter]::GetBytes($Value))
}

function Write-U32([byte[]]$Bytes, [int]$Offset, [UInt32]$Value) {
    Put-Bytes $Bytes $Offset ([BitConverter]::GetBytes($Value))
}

function Write-I32([byte[]]$Bytes, [int]$Offset, [Int32]$Value) {
    Put-Bytes $Bytes $Offset ([BitConverter]::GetBytes($Value))
}

function Align-Up([UInt32]$Value, [UInt32]$Alignment) {
    return [UInt32]([Math]::Ceiling([double]$Value / [double]$Alignment) * [double]$Alignment)
}

function Patch-OperationNeptune([string]$InputExe, [string]$OutputExe, [string]$ScalerBlob) {
    Write-Status 'Patching ONWIN32.EXE...'

    if ((Get-Sha256 $InputExe) -ne $KnownExeSha256) {
        throw 'ONWIN32.EXE does not match the supported original build.'
    }

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($InputExe)

    # Windows 11 display-depth gate: bypass obsolete 8-bit/256-color refusal.
    $displayOffset = 0x4C98
    [byte[]]$displayOld = 0x6A,0x0E,0x53,0xE8,0xA7
    [byte[]]$displayNew = 0xE9,0x71,0x00,0x00,0x00
    Assert-Bytes $bytes $displayOffset $displayOld 'Display compatibility patch'
    Put-Bytes $bytes $displayOffset $displayNew

    # Add the tested 2x WinG presentation + mouse-coordinate shim as a new PE section.
    [byte[]]$shim = [System.IO.File]::ReadAllBytes($ScalerBlob)
    if ($shim.Length -ne 178) {
        throw "Unexpected scaler blob size: $($shim.Length) bytes (expected 178)."
    }

    $pe = [int](Read-U32 $bytes 0x3C)
    if ([System.Text.Encoding]::ASCII.GetString($bytes, $pe, 4) -ne "PE`0`0") {
        throw 'ONWIN32.EXE is not the expected PE executable.'
    }

    $coff = $pe + 4
    $sectionCount = [int](Read-U16 $bytes ($coff + 2))
    $optionalSize = [int](Read-U16 $bytes ($coff + 16))
    $optional = $coff + 20

    if ((Read-U16 $bytes $optional) -ne 0x10B) {
        throw 'Expected a 32-bit PE optional header.'
    }

    $sizeOfCode = [UInt32](Read-U32 $bytes ($optional + 4))
    $imageBase = [UInt32](Read-U32 $bytes ($optional + 28))
    $sectionAlignment = [UInt32](Read-U32 $bytes ($optional + 32))
    $fileAlignment = [UInt32](Read-U32 $bytes ($optional + 36))
    $sizeOfImage = [UInt32](Read-U32 $bytes ($optional + 56))
    $sizeOfHeaders = [UInt32](Read-U32 $bytes ($optional + 60))
    $sectionTable = $optional + $optionalSize

    if (($sectionCount -ne 6) -or ($imageBase -ne 0x00400000) -or ($sizeOfImage -ne 0x00090000)) {
        throw 'Supported executable structure was not found.'
    }

    $newRva = $sizeOfImage
    $newVa = [UInt32]($imageBase + $newRva)
    $newRaw = Align-Up ([UInt32]($bytes.Length)) $fileAlignment
    $newVirtualSize = [UInt32]($shim.Length)
    $newRawSize = Align-Up $newVirtualSize $fileAlignment
    $newSizeOfImage = Align-Up ([UInt32]($newRva + $newVirtualSize)) $sectionAlignment
    $newSectionHeader = $sectionTable + ($sectionCount * 40)

    if (($newSectionHeader + 40) -gt $sizeOfHeaders) {
        throw 'There is no room for the compatibility section header.'
    }

    $newLength = [int]($newRaw + $newRawSize)
    [byte[]]$expanded = New-Object byte[] $newLength
    [Array]::Copy($bytes, 0, $expanded, 0, $bytes.Length)
    [Array]::Copy($shim, 0, $expanded, [int]$newRaw, $shim.Length)
    $bytes = $expanded

    # IMAGE_SECTION_HEADER for W9XSCL.
    [byte[]]$sectionName = 0x57,0x39,0x58,0x53,0x43,0x4C,0x00,0x00
    Put-Bytes $bytes $newSectionHeader $sectionName
    Write-U32 $bytes ($newSectionHeader + 8)  $newVirtualSize
    Write-U32 $bytes ($newSectionHeader + 12) $newRva
    Write-U32 $bytes ($newSectionHeader + 16) $newRawSize
    Write-U32 $bytes ($newSectionHeader + 20) $newRaw
    Write-U32 $bytes ($newSectionHeader + 24) 0
    Write-U32 $bytes ($newSectionHeader + 28) 0
    Write-U16 $bytes ($newSectionHeader + 32) 0
    Write-U16 $bytes ($newSectionHeader + 34) 0
    Write-U32 $bytes ($newSectionHeader + 36) 0x60000020

    Write-U16 $bytes ($coff + 2) ([UInt16]($sectionCount + 1))
    Write-U32 $bytes ($optional + 4) ([UInt32]($sizeOfCode + $newRawSize))
    Write-U32 $bytes ($optional + 56) $newSizeOfImage

    # Redirect the final WinGBitBlt call to our tested 2x scaler.
    $bltVa = 0x00411B37
    $bltOffset = 0x2337
    [byte[]]$bltOld = 0xFF,0x15,0x44,0x6C,0x44,0x00
    Assert-Bytes $bytes $bltOffset $bltOld 'WinG presentation hook'
    [Int32]$bltRel = [Int32]($newVa - ($bltVa + 5))
    [byte[]]$bltNew = New-Object byte[] 6
    $bltNew[0] = 0xE8
    [Array]::Copy([BitConverter]::GetBytes($bltRel), 0, $bltNew, 1, 4)
    $bltNew[5] = 0x90
    Put-Bytes $bytes $bltOffset $bltNew

    # Redirect WndProc entry through the inverse 2x mouse-coordinate transform.
    $wndVa = 0x0041306F
    $wndOffset = 0x386F
    [byte[]]$wndOld = 0x55,0x8B,0xEC,0x83,0xC4,0x84
    Assert-Bytes $bytes $wndOffset $wndOld 'Mouse-coordinate hook'
    $mouseShimOffset = 0x4D
    [UInt32]$mouseVa = [UInt32]($newVa + $mouseShimOffset)
    [Int32]$wndRel = [Int32]($mouseVa - ($wndVa + 5))
    [byte[]]$wndNew = New-Object byte[] 6
    $wndNew[0] = 0xE9
    [Array]::Copy([BitConverter]::GetBytes($wndRel), 0, $wndNew, 1, 4)
    $wndNew[5] = 0x90
    Put-Bytes $bytes $wndOffset $wndNew

    [System.IO.File]::WriteAllBytes($OutputExe, $bytes)

    $actual = Get-Sha256 $OutputExe
    if ($actual -ne $ExpectedPatchedExeSha256) {
        throw "Patched EXE verification failed. Expected $ExpectedPatchedExeSha256, got $actual."
    }
}

function Patch-WinG([string]$InputDll, [string]$OutputDll) {
    Write-Status 'Patching WING32.DLL for portable/local loading...'

    if ((Get-Sha256 $InputDll) -ne $KnownWingSha256) {
        throw 'WING32.DLL does not match the supported original WinG build.'
    }

    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($InputDll)
    $offset = 0x9D4
    [byte[]]$old = 0x81,0xEC,0xA8,0x04,0x00,0x00
    [byte[]]$new = 0xB8,0x01,0x00,0x00,0x00,0xC3
    Assert-Bytes $bytes $offset $old 'WinG installation-location patch'
    Put-Bytes $bytes $offset $new
    [System.IO.File]::WriteAllBytes($OutputDll, $bytes)

    $actual = Get-Sha256 $OutputDll
    if ($actual -ne $ExpectedPatchedWingSha256) {
        throw "Patched WinG verification failed. Expected $ExpectedPatchedWingSha256, got $actual."
    }
}

try {
    Write-Host ''
    Write-Host "Operation Neptune Windows 11 Compatibility Patch $PatchVersion"
    Write-Host 'This patcher does not include or download the game.'
    Write-Host ''

    if ([string]::IsNullOrWhiteSpace($Source)) {
        $Source = Select-Folder 'Select the original Operation Neptune CD, extracted CD folder, or a folder containing the original ONWIN32.EXE.'
    }
    $Source = [System.IO.Path]::GetFullPath($Source)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source folder not found: $Source"
    }

    Write-Status 'Looking for the supported original ONWIN32.EXE...'
    $originalExe = Find-FileByHash $Source 'ONWIN32.EXE' $KnownExeSha256
    if ($null -eq $originalExe) {
        throw "The supported original ONWIN32.EXE was not found under '$Source'."
    }
    $gameRoot = Split-Path -Parent $originalExe
    Write-Status "Found original game build: $originalExe"

    $requiredFiles = @(
        'NEP256.DLL',
        'NEP.DLL',
        'NE0SOUND.DLL',
        'NEPBG1.DLL',
        'NEPBG2.DLL',
        'NE1SOUND.DLL'
    )
    foreach ($name in $requiredFiles) {
        $path = Join-Path $gameRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required original game file is missing: $path"
        }
    }
    $soundsRoot = Join-Path $gameRoot 'SOUNDS'
    if (-not (Test-Path -LiteralPath $soundsRoot -PathType Container)) {
        throw "Required original SOUNDS folder is missing: $soundsRoot"
    }

    if ([string]::IsNullOrWhiteSpace($Wing32)) {
        Write-Status 'Looking for the supported original WING32.DLL...'
        $Wing32 = Find-FileByHash $Source 'WING32.DLL' $KnownWingSha256
    }
    if ([string]::IsNullOrWhiteSpace($Wing32)) {
        Write-Status 'Looking for Microsoft-compressed WING32.DL_...'
        $Wing32 = Find-FileByHash $Source 'WING32.DL_' $KnownWingCompressedSha256
    }
    if ([string]::IsNullOrWhiteSpace($Wing32)) {
        $wingArchive = Get-ChildItem -LiteralPath $Source -Filter 'WING.Z' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $wingArchive) {
            Write-Status "Found WinG installer archive WING.Z at '$($wingArchive.FullName)'."
            Write-Status 'This release does not unpack InstallShield .Z archives directly; select WING32.DLL or WING32.DL_ from an installed/extracted WinG copy.'
        }
        $Wing32 = Select-File 'Select original WING32.DLL or Microsoft-compressed WING32.DL_' 'WinG runtime (WING32.DLL;WING32.DL_)|WING32.DLL;WING32.DL_|DLL/DL_ files (*.dll;*.dl_)|*.dll;*.dl_|All files (*.*)|*.*'
    }

    $resolvedWinG = Resolve-WinGSource $Wing32
    Write-Status "Found original WinG source ($($resolvedWinG.SourceKind)): $Wing32"

    if ([string]::IsNullOrWhiteSpace($Destination)) {
        $parent = Select-Folder 'Choose where to create the patched Operation Neptune folder.'
        $Destination = Join-Path $parent 'Operation Neptune - Windows 11'
    }
    $Destination = [System.IO.Path]::GetFullPath($Destination)

    if (Test-Path -LiteralPath $Destination) {
        $existing = @(Get-ChildItem -LiteralPath $Destination -Force -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 0) {
            throw "Destination is not empty: $Destination`nChoose an empty/new folder so the patcher cannot overwrite an existing installation."
        }
    } else {
        New-Item -ItemType Directory -Path $Destination | Out-Null
    }

    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $scalerBlob = Join-Path $scriptRoot 'patches\opnep_2x_scaler.bin'
    if (-not (Test-Path -LiteralPath $scalerBlob -PathType Leaf)) {
        throw "Patch data is missing: $scalerBlob"
    }

    Write-Status "Creating patched installation in: $Destination"

    # Copy original data/resources from the user's source.
    foreach ($name in $requiredFiles) {
        Copy-Item -LiteralPath (Join-Path $gameRoot $name) -Destination (Join-Path $Destination $name)
    }
    Copy-Item -LiteralPath $soundsRoot -Destination (Join-Path $Destination 'SOUNDS') -Recurse

    $icon = Join-Path $gameRoot 'ONCD.ICO'
    if (Test-Path -LiteralPath $icon -PathType Leaf) {
        Copy-Item -LiteralPath $icon -Destination (Join-Path $Destination 'ONCD.ICO')
    }

    $users = Join-Path $gameRoot 'ONUSERS.DAT'
    if (Test-Path -LiteralPath $users -PathType Leaf) {
        Copy-Item -LiteralPath $users -Destination (Join-Path $Destination 'ONUSERS.DAT')
        Write-Status 'Copied existing ONUSERS.DAT profile/save data from the source folder.'
    }

    Patch-OperationNeptune $originalExe (Join-Path $Destination 'ONWIN32.EXE') $scalerBlob
    try {
        Patch-WinG $resolvedWinG.Path (Join-Path $Destination 'WING32.DLL')
    }
    finally {
        if ($null -ne $resolvedWinG.TempDir) {
            Remove-Item -LiteralPath $resolvedWinG.TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $ini = "[ONWINCD]`r`nCDDrive=.\`r`nCheckDisplay=FALSE`r`nCheckSound=TRUE`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Destination 'ONWINCD.INI'), $ini, [System.Text.Encoding]::ASCII)

    $launcher = '@echo off' + "`r`n" +
                'cd /d "%~dp0"' + "`r`n" +
                'start "" "ONWIN32.EXE"' + "`r`n"
    [System.IO.File]::WriteAllText((Join-Path $Destination 'Play Operation Neptune.cmd'), $launcher, [System.Text.Encoding]::ASCII)

    $installInfo = @"
Operation Neptune Windows 11 Compatibility Patch $PatchVersion

This folder was generated from user-supplied original game files.
No original Operation Neptune files were distributed with the patcher.

Original ONWIN32.EXE SHA-256:
$KnownExeSha256

Patched ONWIN32.EXE SHA-256:
$ExpectedPatchedExeSha256

Original WING32.DLL SHA-256:
$KnownWingSha256

Patched WING32.DLL SHA-256:
$ExpectedPatchedWingSha256

Applied fixes:
- Windows 11 / modern color-depth startup compatibility
- Local/portable WinG loading (no system-directory installation)
- Tested 2x integer scaling: 640x400 -> 1280x800
- Mouse-coordinate remapping for the scaled viewport
"@
    [System.IO.File]::WriteAllText((Join-Path $Destination 'PATCH-INFO.txt'), $installInfo, [System.Text.Encoding]::UTF8)

    Write-Host ''
    Write-Host 'Success!' -ForegroundColor Green
    Write-Host "Patched installation: $Destination"
    Write-Host "Run: $(Join-Path $Destination 'Play Operation Neptune.cmd')"
    Write-Host ''
}
catch {
    Write-Host ''
    Write-Host 'Patch failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    exit 1
}
