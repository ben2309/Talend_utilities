# Restore_old_design.ps1

---

## Description

**Restore_old_design.ps1** is a PowerShell utility script designed for Talend Studio environments. It recursively traverses the Talend components directory and renames SVG icon files whose name matches their parent folder (e.g., `tFileInputDelimited.svg` inside the `tFileInputDelimited/` folder), as well as their dark mode variants (e.g., `tFileInputDelimited_dark.svg`), by replacing the `.svg` extension with `.svgignore`.

This effectively **hides** the SVG icons from Talend Studio without permanently deleting them, triggering the engine's fallback mechanism to display the legacy `icon32.png` icons instead.

The script supports three execution modes:

| Mode | Description |
|------|-------------|
| **Simulation** (default) | Displays planned actions without making any changes |
| **Write** (`-Activate`) | Applies the renames (`.svg` → `.svgignore`) |
| **Rollback** (`-Rollback [-Activate]`) | Reverts renames (`.svgignore` → `.svg`) |

---

## Context & Motivation

### The New Qlik/Talend Design

Starting from recent releases of Talend Studio (integrated into the Qlik ecosystem), component icons were updated to a new SVG-based design. While this modernizes the visual interface, some teams may prefer or require the **classic icon32.png** display — notably for consistency with existing documentation, screenshots, or user habits.

### The Fallback Mechanism

Talend Studio uses the following icon resolution order for each component:

1. **SVG file** — `<ComponentName>.svg` (and `<ComponentName>_dark.svg` for dark mode)
2. **Fallback PNG** — `icon32.png` — used automatically when no `.svg` file is found

By renaming `.svg` files to `.svgignore`, the script **bypasses** the SVG lookup without deleting the files, causing Talend Studio to fall back to the `icon32.png` icons. This is fully reversible via the `-Rollback` mode.

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Operating System** | Windows ( 10 / 11 ) |
| **PowerShell** | Version 5.1 or higher |
| **Talend Studio** | Installed locally with accessible components directory |
| **Permissions** | Read/Write access to the Talend `components` directory (Administrator recommended) |

> **Note:** Run PowerShell as Administrator to avoid permission errors when renaming files inside Talend's installation directory.

---

## Installation

### 1. Download the script

Clone the repository or download the file directly:

# Option A — Clone
git clone https://github.com/ben2309/Talend_utilities.git
cd rename-talend-svg

# Option B — Direct download (PowerShell)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ben2309/Talend_utilities/refs/heads/main/Restore_old_design.ps1" `
    -OutFile "Restore_old_design.ps1"

### 2. Allow script execution (if needed)

If your PowerShell execution policy blocks scripts, temporarily allow local scripts:

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

### 3. Verify the Talend components path

The default path is:

C:\Talend\studio\plugins\org.talend.designer.components.localprovider_*\components

Adjust the `-ComponentsPath` parameter if your installation differs (see [Parameters](#parameters)).

---

## Usage

### Mode Overview

Restore_old_design.ps1 [-ComponentsPath <string>] [-Activate] [-Rollback]

| Combination | Effect |
|-------------|--------|
| *(no flags)* | **Simulation** — shows planned renames, no changes |
| `-Activate` | **Write** — renames `.svg` → `.svgignore` |
| `-Rollback` | **Simulation Rollback** — shows planned reversals, no changes |
| `-Rollback -Activate` | **Rollback** — renames `.svgignore` → `.svg` |

> **Best practice:** Always run in simulation mode first to review the targeted files before applying changes.

---

### Examples

#### Preview renames (simulation — no modification)

.\Restore_old_design.ps1

*Displays all planned `.svg` → `.svgignore` renames without touching any file.*

---

#### Apply the renames (write mode)

.\Restore_old_design.ps1 -Activate

*Renames all matching `.svg` and `_dark.svg` files to `.svgignore` in the default components directory.*

---

#### Use a custom components path (simulation)

.\Restore_old_design.ps1 -ComponentsPath "D:\Talend\studio\plugins\org.talend.designer.components.localprovider*\components"

*Targets a non-default Talend installation for preview. wildcard is enable to keep the commande line iso depending studio upgrade*

---

#### Use a custom components path (write mode)

.\Restore_old_design.ps1 `
    -ComponentsPath "D:\Talend\studio\plugins\org.talend.designer.components.localprovider*\components" `
    -Activate

*Applies renames to the specified custom path.*

---

#### Preview rollback (simulation — no modification)

.\Restore_old_design.ps1 -Rollback

*Displays all planned `.svgignore` → `.svg` reversals without touching any file.*

---

#### Apply rollback (restore SVG icons)

.\Restore_old_design.ps1 -Rollback -Activate

*Restores all previously renamed `.svgignore` files back to `.svg`.*

---

## Parameters

| Parameter | Type | Mandatory | Default Value | Description |
|-----------|------|-----------|---------------|-------------|
| `ComponentsPath` | `String` | No | `C:\Talend\studio\plugins\`<br>`org.talend.designer.components.localprovider*\components` | Full path to the Talend Studio `components` directory. Supports wildcard resolution for version-specific plugin folder names. |
| `Activate` | `Switch` | No | *(absent — simulation)* | When present, applies the actual file renames. Without this switch, the script runs in **dry-run / simulation mode** and makes no changes. |
| `Rollback` | `Switch` | No | *(absent — rename mode)* | When present, reverses the operation by renaming `.svgignore` files back to `.svg`. Must be combined with `-Activate` to actually apply the rollback; otherwise runs in simulation. |

### Parameter Details

#### `ComponentsPath`

Points to the root of the Talend components directory. Each direct subdirectory is treated as one component (e.g., `tFileInputDelimited/`, `tLogRow/`). The script uses `Get-Item` with wildcard support, so paths containing version numbers can be specified with `*` if needed.

#### `Activate`

Acts as a safety switch. Without `-Activate`, the script is entirely read-only — it only reports what *would* happen. This prevents accidental modifications and allows safe auditing before any change is applied.

#### `Rollback`

Enables the reverse operation. The script looks for files named `<ComponentName>.svgignore` and `<ComponentName>_dark.svgignore` inside each component folder, and renames them back to `.svg`. Combining `-Rollback` with `-Activate` is required to actually perform the restoration.

---

## Rollback

The rollback mechanism allows you to fully **undo** the renaming operation and restore Talend Studio's SVG icons.

### How it works

For each component folder (e.g., `tFileInputDelimited/`), the script checks for:

- `tFileInputDelimited.svgignore`
- `tFileInputDelimited_dark.svgignore`

If found, these files are renamed back to their original `.svg` extension. Only files whose name strictly matches the parent folder name are processed — no other `.svgignore` files are touched.

### Rollback Examples

# Step 1 — Preview the rollback (no changes)
.\Restore_old_design.ps1 -Rollback

# Step 2 — Apply the rollback
.\Restore_old_design.ps1 -Rollback -Activate

After a successful rollback, Talend Studio will resume using SVG icons upon restart.

---

## How It Works

### Directory Traversal

1. The script resolves the `ComponentsPath` (with wildcard support via `Get-Item`).
2. It retrieves all **direct subdirectories** of the components folder using `Get-ChildItem -Directory`.
3. Each subdirectory name is treated as the **component name** (e.g., `tFileInputDelimited`, `tLogRow`, `tMap`).

### Rename Criteria

For each component folder named `<ComponentName>`, the script looks for:

| File | Description |
|------|-------------|
| `<ComponentName>.svg` | Standard icon |
| `<ComponentName>_dark.svg` | Dark mode variant |

Only files whose name **exactly matches** the parent folder name (with or without the `_dark` suffix) are processed. Other SVG files present in the folder are ignored.

### Execution Flow

Resolve ComponentsPath
        │
        ▼
Get all component subfolders
        │
        ▼
For each folder:
    ├─ [Normal mode]   Check for <name>.svg and <name>_dark.svg
    │                  → Rename to .svgignore (or simulate)
    │
    └─ [Rollback mode] Check for <name>.svgignore and <name>_dark.svgignore
                       → Rename to .svg (or simulate)
        │
        ▼
Print execution summary

### Output Summary

At the end of each run, the script prints a summary including:

- Execution mode
- Target directory
- Number of folders analyzed
- Number of files renamed (or to rename in simulation)
- Number of folders without a matching target file
- Number of errors encountered

---

## Important Notes

> ⚠️ **Always run in simulation mode first** to verify which files will be affected before applying any changes.

- **No files are deleted.** The script only renames extensions, making the operation fully reversible.
- **Restart Talend Studio** after applying renames or rollback for the icon changes to take effect.
- **Administrator rights** are recommended when the Talend installation directory is under `C:\Program Files` or `C:\Talend`.
- The **default path** in the script includes a wildcard (`*`). If your wanht to force it or change the repo, you must provide the correct path via `-ComponentsPath`.
- Components **without** a matching SVG file (e.g., those that never had SVG icons) are silently skipped and counted in the "Folders without target" summary metric.
- The `_dark` variant is **optional** — its absence for a given component is normal and does not generate a warning.

---

## Troubleshooting

### The specified directory does not exist

**Error:**
[ERROR] The specified directory does not exist or is not accessible:
        C:\Talend\studio\plugins\org.talend.designer.components.localprovider*\components

**Solution:**
Verify your Talend Studio installation path. The plugin folder name includes a build date that varies per installation. Use `-ComponentsPath` to specify the correct path:

# Find the correct folder
Get-ChildItem "C:\Talend\studio\plugins\" | Where-Object { $_.Name -like "*localprovider*" }

---

### Access denied / Permission error

**Error:**
[ERROR] Unable to rename: ...
        Detail: Access to the path is denied.

**Solution:**
Run PowerShell as **Administrator**. Right-click on PowerShell → *Run as Administrator*, then re-execute the script.

---

### Script execution is blocked

**Error:**
.\Restore_old_design.ps1 : File cannot be loaded because running scripts is disabled on this system.

**Solution:**
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

---

### No files renamed (count = 0)

**Possible causes:**
- The SVG files have already been renamed (run `-Rollback` to check).
- The `ComponentsPath` points to the wrong directory.
- The components in this installation do not have SVG icons (older Talend version).

---

### Icons not updated after script execution

**Solution:**
Fully **close and restart Talend Studio**. The icon cache is loaded at startup and will not refresh during an active session.

---

## License

- The script is provided *as-is*, without warranty of any kind.
- Files are renamed, never deleted — all operations are reversible.

---

## Author

| Field | Value |
|-------|-------|
| **Name** | BARBIERATO Benoit |
| **Email** | bbaconsulting@pm.me |
