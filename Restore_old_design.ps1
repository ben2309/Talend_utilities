#Requires -Version 5.1

<#
.SYNOPSIS
    Renames Talend component SVG files to .svgignore (or the reverse with -Rollback).

.DESCRIPTION
    This script recursively traverses the Talend components directory and renames
    SVG files whose name matches the parent folder name (e.g.: tREST.svg
    in the tREST folder), as well as their dark mode variants (e.g.: tREST_dark.svg).
    The .svg extension is replaced by .svgignore in order to hide SVG icons
    without deleting the files.

    By default, the script runs in SIMULATION mode: no modification is
    performed, only the planned actions are displayed.
    To apply the renames, use the -Activate parameter.
    To undo the renames (.svgignore => .svg), use the -Rollback parameter.

.PARAMETER ComponentsPath
    Path to the Talend Studio "components" directory.
    Default value: C:\Talend\studio\plugins\org.talend.designer.components.localprovider*\components

.PARAMETER Activate
    Switch. Absent by default (simulation mode).
    If present, actually executes the renames (.svg => .svgignore).

.PARAMETER Rollback
    Switch. If present, renames .svgignore files back to .svg
    only if the name matches the parent folder (e.g.: tREST.svgignore
    and tREST_dark.svgignore in the tREST folder).
    Can be combined with -Activate to actually apply the rollback
    (without -Activate, the rollback runs in simulation mode).

.EXAMPLE
    # Preview the renames (simulation mode, no modification)
    .\Restore_old_design.ps1

.EXAMPLE
    # Execute the actual renames (.svg => .svgignore)
    .\Restore_old_design.ps1 -Activate

.EXAMPLE
    # Specify a custom path in simulation mode
    .\Restore_old_design.ps1 -ComponentsPath "D:\Talend\studio\plugins\org.talend.designer.components.localprovider*\components"

.EXAMPLE
    # Specify a custom path and execute the renames
    .\Restore_old_design.ps1 -ComponentsPath "D:\Talend\studio\plugins\org.talend.designer.components.localprovider*\components" -Activate

.EXAMPLE
    # Preview the rollback of renames (.svgignore => .svg)
    .\Restore_old_design.ps1 -Rollback

.EXAMPLE
    # Execute the rollback of renames (.svgignore => .svg)
    .\Restore_old_design.ps1 -Rollback -Activate

.NOTES
    Author  : BARBIERATO Benoit
    IMPORTANT: Run in DRY-RUN mode first to verify the targeted files
    before applying the actual modifications.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    # Default path to the Talend Studio components directory
    [Parameter(Mandatory = $false, HelpMessage = "Path to the Talend components directory")]
    [string]$ComponentsPath = "C:\Talend\studio\plugins\org.talend.designer.components.localprovider*\components",

    # Default: simulation. Use -Activate to apply the actual modifications.
    [Parameter(Mandatory = $false, HelpMessage = "If present, actually executes the renames (.svg => .svgignore). Without this parameter, the script runs in simulation mode.")]
    [switch]$Activate,

    # Rollback mode: renames .svgignore files back to .svg (reverse logic)
    [Parameter(Mandatory = $false, HelpMessage = "If present, renames .svgignore files back to .svg matching the parent folder.")]
    [switch]$Rollback
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

# ====
# SECTION: Initialization and header display
# ====

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Restore_old_design.ps1" -ForegroundColor Cyan
Write-Host "  Renaming Talend SVGs to .svgignore" -ForegroundColor Cyan
Write-Host "  Author  : BARBIERATO Benoit" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan

# Display the current execution mode
if ($Rollback) {
    if ($Activate) {
        Write-Host "[MODE] ROLLBACK — .svgignore files will be renamed to .svg." -ForegroundColor Magenta
    } else {
        Write-Host "[MODE] SIMULATION ROLLBACK — No modification will be performed." -ForegroundColor Yellow
        Write-Host "[MODE] To apply the rollback, re-run with: -Rollback -Activate" -ForegroundColor Yellow
    }
} elseif ($Activate) {
    Write-Host "[MODE] WRITE enabled — .svg files will be renamed to .svgignore." -ForegroundColor Green
} else {
    Write-Host "[MODE] SIMULATION enabled — No modification will be performed." -ForegroundColor Yellow
    Write-Host "[MODE] To apply the renames, re-run with: -Activate" -ForegroundColor Yellow
}

Write-Host "[INFO] Target directory: $ComponentsPath" -ForegroundColor White

# ====
# SECTION: Wildcard resolution of the target directory
# ====

# Resolve the path, which may contain wildcards (e.g.: version number in plugin name)
$resolvedItems = Get-Item -Path $ComponentsPath -ErrorAction SilentlyContinue

if (-not $resolvedItems) {
    Write-Host "[ERROR] The specified directory does not exist or is not accessible:" -ForegroundColor Red
    Write-Host "         $ComponentsPath" -ForegroundColor Red
    Write-Host "[TIP] Check that Talend Studio is properly installed and that the path is correct." -ForegroundColor Yellow
    Write-Host "      The version number in the plugin name may vary depending on your installation." -ForegroundColor Yellow
    exit 1
}

# If multiple matches, use the first one (most recent or only result)
$ComponentsPath = $resolvedItems[0].FullName

Write-Host "[INFO] Resolved target directory: $ComponentsPath" -ForegroundColor White

# ====
# SECTION: Retrieving component subfolders
# ====

Write-Host "[INFO] Retrieving component subfolders..." -ForegroundColor White

# Retrieves all direct subfolders of the components directory
# Each subfolder corresponds to a Talend component (e.g.: tREST, tPrejob, ...)
try {
    $componentFolders = Get-ChildItem -Path $ComponentsPath -Directory -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Unable to read the directory: $ComponentsPath" -ForegroundColor Red
    Write-Host "        Detail: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check that there are folders to process
if ($componentFolders.Count -eq 0) {
    Write-Host "[WARNING] No subfolder found in: $ComponentsPath" -ForegroundColor Yellow
    Write-Host "          The directory appears to be empty." -ForegroundColor Yellow
    exit 0
}

Write-Host "[INFO] $($componentFolders.Count) component folder(s) found." -ForegroundColor White

# ====
# SECTION: Counters for the final summary
# ====

$countRenamed   = 0   # Number of files renamed (or that would have been renamed in dry-run)
$countSkipped   = 0   # Number of SVG files found but not matching the criterion
$countErrors    = 0   # Number of errors encountered during renames
$countNoSvg     = 0   # Number of folders without a matching SVG file

# ====
# SECTION: Folder traversal and SVG file processing
# ====

if ($Rollback) {
    Write-Host "[INFO] Starting component traversal (ROLLBACK mode: .svgignore => .svg)..." -ForegroundColor White
} else {
    Write-Host "[INFO] Starting component traversal (RENAME mode: .svg => .svgignore)..." -ForegroundColor White
}
Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($folder in $componentFolders) {

    # Component name = folder name (e.g.: tREST)
    $componentName = $folder.Name

    $foundAny = $false  # Indicates whether at least one matching file was found in this folder

    if ($Rollback) {

        # -------------------------------------------------------
        # ROLLBACK MODE: renames .svgignore files back to .svg
        # Only files whose name matches the parent folder are processed
        # -------------------------------------------------------
        $expectedSvgIgnoreFiles = @(
            ($componentName + ".svgignore"),
            ($componentName + "_dark.svgignore")
        )

        foreach ($svgIgnoreFileName in $expectedSvgIgnoreFiles) {

            $svgIgnoreFilePath = Join-Path -Path $folder.FullName -ChildPath $svgIgnoreFileName

            if (Test-Path -Path $svgIgnoreFilePath -PathType Leaf) {

                $foundAny = $true

                # New name: replace .svgignore with .svg
                $newFileName = [System.IO.Path]::GetFileNameWithoutExtension($svgIgnoreFileName) + ".svg"
                $newFilePath = Join-Path -Path $folder.FullName -ChildPath $newFileName

                if (-not $Activate) {
                    # --- SIMULATION ROLLBACK MODE ---
                    Write-Host "[SIMULATION] Planned rollback:" -ForegroundColor Yellow -NoNewline
                    Write-Host " $svgIgnoreFilePath" -ForegroundColor White -NoNewline
                    Write-Host " --> " -ForegroundColor DarkGray -NoNewline
                    Write-Host "$newFileName" -ForegroundColor Magenta
                    $countRenamed++
                } else {
                    # --- ACTUAL ROLLBACK MODE ---
                    try {
                        Rename-Item -Path $svgIgnoreFilePath -NewName $newFileName -ErrorAction Stop
                        Write-Host "[OK] Rollback: $svgIgnoreFilePath --> $newFileName" -ForegroundColor Magenta
                        $countRenamed++
                    } catch {
                        Write-Host "[ERROR] Unable to rename: $svgIgnoreFilePath" -ForegroundColor Red
                        Write-Host "        Detail: $($_.Exception.Message)" -ForegroundColor Red
                        $countErrors++
                    }
                }
            }
        }

    } else {

        # -------------------------------------------------------
        # NORMAL MODE: renames .svg files to .svgignore
        # Building expected SVG file names for this component:
        #   - Standard file: tREST.svg
        #   - Dark mode file: tREST_dark.svg
        # -------------------------------------------------------
        $expectedSvgFiles = @(
            ($componentName + ".svg"),
            ($componentName + "_dark.svg")
        )

        foreach ($svgFileName in $expectedSvgFiles) {

            # Full path of the expected SVG file
            $svgFilePath = Join-Path -Path $folder.FullName -ChildPath $svgFileName

            # Check for the existence of the SVG file
            if (Test-Path -Path $svgFilePath -PathType Leaf) {

                $foundAny = $true

                # Build the new file name with the .svgignore extension
                $newFileName = [System.IO.Path]::GetFileNameWithoutExtension($svgFileName) + ".svgignore"
                $newFilePath = Join-Path -Path $folder.FullName -ChildPath $newFileName

                if (-not $Activate) {
                    # --- SIMULATION MODE: display only, no modification ---
                    Write-Host "[SIMULATION] Planned rename:" -ForegroundColor Yellow -NoNewline
                    Write-Host " $svgFilePath" -ForegroundColor White -NoNewline
                    Write-Host " --> " -ForegroundColor DarkGray -NoNewline
                    Write-Host "$newFileName" -ForegroundColor Green
                    $countRenamed++

                } else {
                    # --- WRITE MODE: actual file rename ---
                    try {
                        Rename-Item -Path $svgFilePath -NewName $newFileName -ErrorAction Stop
                        Write-Host "[OK] Renamed: $svgFilePath --> $newFileName" -ForegroundColor Green
                        $countRenamed++
                    } catch {
                        Write-Host "[ERROR] Unable to rename: $svgFilePath" -ForegroundColor Red
                        Write-Host "        Detail: $($_.Exception.Message)" -ForegroundColor Red
                        $countErrors++
                    }
                }

            }
            # If the SVG file does not exist for this component, nothing is reported
            # (some components may not have a _dark variant, this is normal)
        }

    }

    # If no matching file was found in this folder
    if (-not $foundAny) {
        $countNoSvg++
        Write-Verbose "[VERBOSE] No matching file found in: $($folder.FullName)"
    }
}

# ====
# SECTION: Final summary
# ====

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($Rollback) {
    if ($Activate) {
        Write-Host "  Mode         : ROLLBACK (.svgignore => .svg renames applied)" -ForegroundColor Magenta
    } else {
        Write-Host "  Mode         : SIMULATION ROLLBACK (no modification performed)" -ForegroundColor Yellow
    }
} elseif ($Activate) {
    Write-Host "  Mode         : WRITE (.svg => .svgignore renames applied)" -ForegroundColor Green
} else {
    Write-Host "  Mode         : SIMULATION (no modification performed)" -ForegroundColor Yellow
}

Write-Host "  Directory    : $ComponentsPath" -ForegroundColor White
Write-Host "  Folders analyzed        : $($componentFolders.Count)" -ForegroundColor White

if ($Activate) {
    Write-Host "  Files renamed           : $countRenamed" -ForegroundColor Green
} else {
    Write-Host "  Files to rename         : $countRenamed" -ForegroundColor Yellow
}

Write-Host "  Folders without target  : $countNoSvg" -ForegroundColor Gray

if ($countErrors -gt 0) {
    Write-Host "  Errors encountered      : $countErrors" -ForegroundColor Red
} else {
    Write-Host "  Errors encountered      : $countErrors" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Cyan

if (-not $Activate) {
    Write-Host ""
    Write-Host "[REMINDER] No modification has been performed (SIMULATION mode)." -ForegroundColor Yellow
    if ($Rollback) {
        Write-Host "           To apply the rollback, run:" -ForegroundColor Yellow
        Write-Host "           .\Restore_old_design.ps1 -Rollback -Activate" -ForegroundColor Cyan
    } else {
        Write-Host "           To apply the renames, run:" -ForegroundColor Yellow
        Write-Host "           .\Restore_old_design.ps1 -Activate" -ForegroundColor Cyan
    }
}

Write-Host ""
