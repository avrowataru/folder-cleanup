param(
    [string]$Root = (Get-Location).Path,
    [string]$FfprobePath = ""
)

$videoExts = @('.mkv', '.mp4', '.avi', '.mov', '.wmv', '.m4v')
$subExts   = @('.srt')
$parent    = (Resolve-Path $Root).Path

Write-Host "=== Starting Folder Cleanup ===" -ForegroundColor Cyan
Write-Host "Working folder: $parent"
Write-Host ""

function Find-Ffprobe {
    param([string]$PreferredPath)

    if ($PreferredPath -and (Test-Path -LiteralPath $PreferredPath)) {
        return $PreferredPath
    }

    $cmd = Get-Command ffprobe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

$ffprobe = Find-Ffprobe -PreferredPath $FfprobePath
if ($ffprobe) {
    Write-Host "ffprobe found: $ffprobe" -ForegroundColor Green
} else {
    Write-Host "ffprobe not found. Resolution tag will be omitted." -ForegroundColor Yellow
}
Write-Host ""

function Get-ResolutionTag {
    param(
        [string]$VideoPath,
        [string]$FfprobeExe
    )

    if (-not $FfprobeExe) { return $null }

    try {
        $dims = & $FfprobeExe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$VideoPath" 2>$null
        $dims = ($dims | Select-Object -First 1).ToString().Trim()

        if (-not $dims -or $dims -notmatch '^(\d+)x(\d+)$') {
            return $null
        }

        $width  = [int]$matches[1]
        $height = [int]$matches[2]

        if ($width -ge 3800 -or $height -ge 2000) { return '2160p' }
        elseif ($width -ge 1900 -or $height -ge 1000) { return '1080p' }
        elseif ($width -ge 1200 -or $height -ge 700) { return '720p' }
        elseif ($width -ge 700 -or $height -ge 500) { return '480p' }
        else { return "$height`p" }
    }
    catch {
        return $null
    }
}

function Get-CleanBaseName {
    param(
        [string]$BaseName,
        [string]$ResolutionTag
    )

    $name = $BaseName

    if ($name -match '^(.*?)\s*\((\d{4})\)') {
        $title = $matches[1].Trim()
        $year  = $matches[2]
        $name  = "$title ($year)"
    }
    else {
        $name = $name -replace '^www\.[^\s]+\s*-\s*', ''
        $name = $name -replace '\s*\[[^\]]*\]', ''
        $name = $name -replace '(?i)\b(720p|1080p|2160p|4k|bluray|webrip|web-dl|hdrip|x264|x265|hevc|avc|aac|dd5\.1|10bit|yts\.\w+|exyusubs)\b', ' '
        $name = $name -replace '[._-]+', ' '
        $name = $name -replace '\s+', ' '
        $name = $name.Trim()

        if ($name -match '^(.*?)(\d{4})\b') {
            $title = $matches[1].Trim()
            $year  = $matches[2]
            $name  = "$title ($year)"
        }
    }

    $name = $name.Trim(' ', '.', '-', '_')

    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $BaseName.Trim()
    }

    if ($ResolutionTag) {
        $name = "$name [$ResolutionTag]"
    }

    return $name
}

function Get-UniqueTargetPath {
    param(
        [string]$Folder,
        [string]$BaseName,
        [string]$Extension,
        [string]$CurrentFullName = ""
    )

    $candidate = Join-Path $Folder ($BaseName + $Extension)
    $i = 1
    while ((Test-Path -LiteralPath $candidate) -and ((Resolve-Path -LiteralPath $candidate).Path -ne $CurrentFullName)) {
        $candidate = Join-Path $Folder ("{0} ({1}){2}" -f $BaseName, $i, $Extension)
        $i++
    }
    return $candidate
}

Write-Host "--- Step 1: Moving video and matching subtitle files from subfolders ---" -ForegroundColor Yellow

$videos = Get-ChildItem -Path $parent -File -Recurse | Where-Object {
    $_.DirectoryName -ne $parent -and $videoExts -contains $_.Extension.ToLower()
} | Sort-Object FullName

if (-not $videos) {
    Write-Host "  No video files found in subfolders." -ForegroundColor Gray
}
else {
    foreach ($video in $videos) {
        $sourceDir         = $video.DirectoryName
        $originalVideoBase = $video.BaseName
        $resolutionTag     = Get-ResolutionTag -VideoPath $video.FullName -FfprobeExe $ffprobe
        $cleanBase         = Get-CleanBaseName -BaseName $video.BaseName -ResolutionTag $resolutionTag
        $videoTarget       = Get-UniqueTargetPath -Folder $parent -BaseName $cleanBase -Extension $video.Extension.ToLower() -CurrentFullName $video.FullName
        $finalVideoBase    = [System.IO.Path]::GetFileNameWithoutExtension($videoTarget)

        Write-Host "  [VIDEO] Moving:" -ForegroundColor Green
        Write-Host "    FROM: $($video.FullName)"
        Write-Host "    TO:   $videoTarget"
        if ($resolutionTag) {
            Write-Host "    META: resolution=$resolutionTag"
        }

        Move-Item -LiteralPath $video.FullName -Destination $videoTarget -ErrorAction Stop

        Get-ChildItem -Path $sourceDir -File | Where-Object {
            $subExts -contains $_.Extension.ToLower() -and $_.BaseName -eq $originalVideoBase
        } | ForEach-Object {
            $subTarget = Get-UniqueTargetPath -Folder $parent -BaseName $finalVideoBase -Extension $_.Extension.ToLower() -CurrentFullName $_.FullName
            Write-Host "  [SUB]   Moving:" -ForegroundColor Cyan
            Write-Host "    FROM: $($_.FullName)"
            Write-Host "    TO:   $subTarget"
            Move-Item -LiteralPath $_.FullName -Destination $subTarget -ErrorAction Stop
        }
    }
}

Write-Host ""
Write-Host "--- Step 2: Renaming video files already in parent ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -File | Where-Object {
    $videoExts -contains $_.Extension.ToLower()
} | ForEach-Object {
    $resolutionTag = Get-ResolutionTag -VideoPath $_.FullName -FfprobeExe $ffprobe
    $cleanBase = Get-CleanBaseName -BaseName $_.BaseName -ResolutionTag $resolutionTag
    $newTarget = Get-UniqueTargetPath -Folder $parent -BaseName $cleanBase -Extension $_.Extension.ToLower() -CurrentFullName $_.FullName

    if ($_.FullName -ne $newTarget) {
        Write-Host "  [RENAME] $($_.Name) => $(Split-Path $newTarget -Leaf)" -ForegroundColor Green
        Rename-Item -LiteralPath $_.FullName -NewName (Split-Path $newTarget -Leaf) -ErrorAction Stop
    }
}

Write-Host ""
Write-Host "--- Step 3: Renaming subtitle files already in parent ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -File | Where-Object {
    $subExts -contains $_.Extension.ToLower()
} | ForEach-Object {
    $cleanBase = Get-CleanBaseName -BaseName $_.BaseName -ResolutionTag $null
    $newTarget = Get-UniqueTargetPath -Folder $parent -BaseName $cleanBase -Extension $_.Extension.ToLower() -CurrentFullName $_.FullName

    if ($_.FullName -ne $newTarget) {
        Write-Host "  [RENAME] $($_.Name) => $(Split-Path $newTarget -Leaf)" -ForegroundColor Green
        Rename-Item -LiteralPath $_.FullName -NewName (Split-Path $newTarget -Leaf) -ErrorAction Stop
    }
}

Write-Host ""
Write-Host "--- Step 4: Deleting leftover junk files in subfolders ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -File -Recurse | Where-Object {
    $_.DirectoryName -ne $parent -and ($videoExts + $subExts) -notcontains $_.Extension.ToLower()
} | ForEach-Object {
    Write-Host "  [DELETE] $($_.FullName)" -ForegroundColor Red
    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "--- Step 5: Deleting leftover subtitle files in subfolders ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -File -Recurse | Where-Object {
    $_.DirectoryName -ne $parent -and $subExts -contains $_.Extension.ToLower()
} | ForEach-Object {
    Write-Host "  [DELETE] $($_.FullName)" -ForegroundColor Red
    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "--- Step 6: Deleting empty subfolders ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -Directory -Recurse |
    Sort-Object FullName -Descending |
    Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
    ForEach-Object {
        Write-Host "  [RMDIR] $($_.FullName)" -ForegroundColor Red
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
