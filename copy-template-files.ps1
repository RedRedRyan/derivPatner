<#
.SYNOPSIS
  Copy specific paths from a bot-builder template repo into derivPatner,
  with a dry-run mode that reports NEW / CONFLICT / IDENTICAL before anything is touched.

.PARAMETER SourceRoot
  Root of the template repo (e.g. the bot-builder project you're pulling from).

.PARAMETER DestRoot
  Root of derivPatner (or wherever you're copying into).

.PARAMETER Paths
  One or more relative paths (files or folders) to copy, relative to SourceRoot/src
  (or pass -RelativeToSrc:$false to use paths relative to SourceRoot directly).

.PARAMETER Apply
  Without this switch, the script only reports what WOULD happen (dry run).
  Pass -Apply to actually perform the copy.

.PARAMETER RelativeToSrc
  Default $true. If your paths are like 'external/bot-skeleton', they get resolved
  as SourceRoot/src/external/bot-skeleton -> DestRoot/src/external/bot-skeleton.
  Set to $false if you want to pass full relative-to-root paths instead.

.EXAMPLE
  # Dry run first (default) - see what's new vs conflicting
  .\copy-template-files.ps1 `
    -SourceRoot "C:\Users\Dell\works\bot-builder-template" `
    -DestRoot "C:\Users\Dell\works\derivPatner" `
    -Paths "external/bot-skeleton", "pages/bot-builder/quick-strategy", "components/transactions", "components/shared/src/utils/contract", "services/derivws-accounts.service.ts"

.EXAMPLE
  # Once you've reviewed the report, actually copy
  .\copy-template-files.ps1 `
    -SourceRoot "C:\Users\Dell\works\bot-builder-template" `
    -DestRoot "C:\Users\Dell\works\derivPatner" `
    -Paths "external/bot-skeleton" `
    -Apply
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$DestRoot,

    [Parameter(Mandatory = $true)]
    [string[]]$Paths,

    [switch]$Apply,

    [bool]$RelativeToSrc = $true,

    # If set, conflicting files get backed up to <file>.bak-<timestamp> before overwrite.
    [bool]$BackupOnOverwrite = $true
)

function Resolve-Pair {
    param([string]$RelPath)

    if ($RelativeToSrc) {
        $src = Join-Path (Join-Path $SourceRoot "src") $RelPath
        $dst = Join-Path (Join-Path $DestRoot "src") $RelPath
    } else {
        $src = Join-Path $SourceRoot $RelPath
        $dst = Join-Path $DestRoot $RelPath
    }
    return [PSCustomObject]@{ Source = $src; Dest = $dst; Relative = $RelPath }
}

function Get-FileList {
    param([string]$RootItem)

    if (-not (Test-Path $RootItem)) {
        return @()
    }
    if ((Get-Item $RootItem).PSIsContainer) {
        return Get-ChildItem -Path $RootItem -Recurse -File | ForEach-Object { $_.FullName }
    } else {
        return @($RootItem)
    }
}

$report = @()

foreach ($p in $Paths) {
    $pair = Resolve-Pair -RelPath $p

    if (-not (Test-Path $pair.Source)) {
        $report += [PSCustomObject]@{
            RelativePath = $p
            File         = "(entire path)"
            Status       = "SOURCE MISSING"
            SourcePath   = $pair.Source
            DestPath     = $pair.Dest
        }
        continue
    }

    $sourceFiles = Get-FileList -RootItem $pair.Source

    foreach ($sf in $sourceFiles) {
        # Compute the destination path by swapping the source root prefix for the dest root prefix
        $relFromSourceItem = $sf.Substring($pair.Source.Length).TrimStart('\', '/')
        $df = if ((Get-Item $pair.Source).PSIsContainer) {
            Join-Path $pair.Dest $relFromSourceItem
        } else {
            $pair.Dest
        }

        if (-not (Test-Path $df)) {
            $status = "NEW"
        } else {
            $srcHash = (Get-FileHash -Path $sf -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash -Path $df -Algorithm SHA256).Hash
            $status = if ($srcHash -eq $dstHash) { "IDENTICAL" } else { "CONFLICT (differs)" }
        }

        $report += [PSCustomObject]@{
            RelativePath = $p
            File         = $relFromSourceItem
            Status       = $status
            SourcePath   = $sf
            DestPath     = $df
        }
    }
}

Write-Host ""
Write-Host "=== Copy Report: $SourceRoot  ->  $DestRoot ===" -ForegroundColor Cyan
Write-Host ""

$report | Group-Object RelativePath | ForEach-Object {
    Write-Host "--- $($_.Name) ---" -ForegroundColor Yellow
    $_.Group | Format-Table File, Status -AutoSize
}

$newCount      = ($report | Where-Object { $_.Status -eq "NEW" }).Count
$conflictCount = ($report | Where-Object { $_.Status -like "CONFLICT*" }).Count
$identCount    = ($report | Where-Object { $_.Status -eq "IDENTICAL" }).Count
$missingCount  = ($report | Where-Object { $_.Status -eq "SOURCE MISSING" }).Count

Write-Host ""
Write-Host "Summary: $newCount new | $conflictCount conflicting | $identCount identical | $missingCount source-missing" -ForegroundColor Cyan
Write-Host ""

if (-not $Apply) {
    Write-Host "DRY RUN - no files were copied. Re-run with -Apply to perform the copy." -ForegroundColor Green
    Write-Host "Review CONFLICT entries above carefully before applying - these will overwrite existing derivPatner files." -ForegroundColor Green
    return
}

# --- Apply phase ---
if ($conflictCount -gt 0) {
    Write-Host "WARNING: $conflictCount file(s) differ from source and will be overwritten." -ForegroundColor Red
    $confirm = Read-Host "Type YES to continue with the copy"
    if ($confirm -ne "YES") {
        Write-Host "Aborted. No files were copied." -ForegroundColor Red
        return
    }
}

foreach ($row in $report) {
    if ($row.Status -eq "SOURCE MISSING" -or $row.Status -eq "IDENTICAL") {
        continue
    }

    $destDir = Split-Path -Parent $row.DestPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    if ($row.Status -like "CONFLICT*" -and $BackupOnOverwrite -and (Test-Path $row.DestPath)) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -Path $row.DestPath -Destination "$($row.DestPath).bak-$stamp" -Force
    }

    Copy-Item -Path $row.SourcePath -Destination $row.DestPath -Force
    Write-Host "Copied: $($row.RelativePath)/$($row.File)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Done. $newCount new file(s), $conflictCount overwritten (backups saved as .bak-<timestamp>)." -ForegroundColor Green
