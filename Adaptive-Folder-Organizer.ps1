param(
    [string]$Root = (Get-Location).Path,
    [string]$FfprobePath = ""
)

# Rule Engine Configuration
$Rules = @{
    VideoExtensions    = @('.mkv', '.mp4', '.avi', '.mov', '.wmv', '.m4v')
    SubtitleExtensions = @('.srt', '.sub', '.ass')
    JunkExtensions     = @('.nfo', '.txt', '.jpg', '.png', '.url', '.exe', '.zip', '.rar')
    DeleteJunkFiles    = $true
    DeleteEmptyFolders = $true
    CleanupPatterns    = @(
        '^(?:www\.[^\s]+\s*-\s*)',
        '(?:\s*-\s*www\.[^\s]+)$',
        '\s*\[[^\]]*\]',
        '(?i)\b(720p|1080p|2160p|4k|bluray|webrip|web-dl|hdrip|x264|x265|hevc|avc|aac|dd5\.1|10bit|yts\.\w+|exyusubs|xrg|true\s+web-dl|sdr|atmos)\b'
    )
}

$parent = (Resolve-Path $Root).Path

Write-Host "=== Adaptive Folder Organizer Engine ===" -ForegroundColor Cyan
Write-Host "Working folder: $parent"
Write-Host ""

function Find-Ffprobe {
    param([string]$PreferredPath)
    if ($PreferredPath -and (Test-Path -LiteralPath $PreferredPath)) { return $PreferredPath }
    $cmd = Get-Command ffprobe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$ffprobe = Find-Ffprobe -PreferredPath $FfprobePath
if ($ffprobe) { Write-Host "ffprobe found: $ffprobe" -ForegroundColor Green }
else { Write-Host "ffprobe not found. Resolution tag will be omitted." -ForegroundColor Yellow }

function Get-ResolutionTag {
    param([string]$VideoPath, [string]$FfprobeExe)
    if (-not $FfprobeExe) { return $null }
    try {
        $dims = & $FfprobeExe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$VideoPath" 2>$null
        $dims = ($dims | Select-Object -First 1).ToString().Trim()
        if (-not $dims -or $dims -notmatch '^(\d+)x(\d+)$') { return $null }
        $width  = [int]$matches[1]
        $height = [int]$matches[2]
        
        # Adaptive checking
        if ($width -ge 3800 -or $height -ge 2000) { return '2160p' }
        elseif ($width -ge 1900 -or $height -ge 1000) { return '1080p' }
        elseif ($width -ge 1200 -or $height -ge 700) { return '720p' }
        elseif ($width -ge 700 -or $height -ge 500) { return '480p' }
        else { return "$height`p" }
    } catch { return $null }
}

function Get-CleanBaseName {
    param([string]$BaseName, [string]$ResolutionTag, [hashtable]$RulesConfig)
    
    $name = $BaseName
    
    # Apply cleanup patterns
    foreach ($pattern in $RulesConfig.CleanupPatterns) {
        $name = $name -replace $pattern, ' '
    }
    
    # Extract up to the first (Year) or Year if present
    if ($name -match '^(.+?\(\d{4}\))') {
        $name = $matches[1]
    } elseif ($name -match '^(.+?\b\d{4}\b)') {
        $titleWithYear = $matches[1]
        if ($titleWithYear -match '^(.*?)\s*(\d{4})$') {
            $name = "$($matches[1].Trim()) ($($matches[2]))"
        } else {
            $name = $titleWithYear
        }
    }
    
    # Clean up trailing hyphens and spaces
    $name = $name -replace '(?:\s*-)+\s*$', ''
    # Clean up dots and underscores, but preserve hyphens for names like "Pre-Wedding"
    $name = $name -replace '[._]+', ' '
    $name = $name -replace '\s+', ' '
    $name = $name.Trim(' ', '-')
    
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $BaseName.Trim() }
    
    if ($ResolutionTag) { $name = "$name [$ResolutionTag]" }
    
    return $name
}

function Get-UniqueTargetPath {
    param([string]$Folder, [string]$BaseName, [string]$Extension, [string]$CurrentFullName = "")
    $candidate = Join-Path $Folder ($BaseName + $Extension)
    $i = 1
    while ((Test-Path -LiteralPath $candidate) -and ((Resolve-Path -LiteralPath $candidate).Path -ne $CurrentFullName)) {
        $candidate = Join-Path $Folder ("{0} ({1}){2}" -f $BaseName, $i, $Extension)
        $i++
    }
    return $candidate
}

# --- ENGINE EXECUTION ---

# Phase 1: Flatten and Organize
Write-Host "--- Phase 1: Organizing Video and Subtitle Files ---" -ForegroundColor Yellow

$allVideos = Get-ChildItem -Path $parent -File -Recurse | Where-Object { $Rules.VideoExtensions -contains $_.Extension.ToLower() } | Sort-Object FullName
foreach ($video in $allVideos) {
    $sourceDir = $video.DirectoryName
    $originalVideoBase = $video.BaseName
    $resTag = Get-ResolutionTag -VideoPath $video.FullName -FfprobeExe $ffprobe
    $cleanBase = Get-CleanBaseName -BaseName $video.BaseName -ResolutionTag $resTag -RulesConfig $Rules
    
    $videoTarget = Get-UniqueTargetPath -Folder $parent -BaseName $cleanBase -Extension $video.Extension.ToLower() -CurrentFullName $video.FullName
    $finalVideoBase = [System.IO.Path]::GetFileNameWithoutExtension($videoTarget)
    
    if ($video.FullName -ne $videoTarget) {
        Write-Host "  [VIDEO] $($video.Name) => $(Split-Path $videoTarget -Leaf)" -ForegroundColor Green
        Move-Item -LiteralPath $video.FullName -Destination $videoTarget -ErrorAction Stop
    }

    # Handle Subtitles in same folder (if nested) or directly
    Get-ChildItem -Path $sourceDir -File | Where-Object {
        $Rules.SubtitleExtensions -contains $_.Extension.ToLower() -and $_.BaseName -eq $originalVideoBase
    } | ForEach-Object {
        $subTarget = Get-UniqueTargetPath -Folder $parent -BaseName $finalVideoBase -Extension $_.Extension.ToLower() -CurrentFullName $_.FullName
        if ($_.FullName -ne $subTarget) {
            Write-Host "  [SUB]   $($_.Name) => $(Split-Path $subTarget -Leaf)" -ForegroundColor Cyan
            Move-Item -LiteralPath $_.FullName -Destination $subTarget -ErrorAction Stop
        }
    }
}

# Phase 2: Orphan Subtitles Renaming (already in root)
Write-Host "`n--- Phase 2: Processing Remaining Root Subtitles ---" -ForegroundColor Yellow
Get-ChildItem -Path $parent -File | Where-Object { $Rules.SubtitleExtensions -contains $_.Extension.ToLower() } | ForEach-Object {
    $cleanBase = Get-CleanBaseName -BaseName $_.BaseName -ResolutionTag $null -RulesConfig $Rules
    $newTarget = Get-UniqueTargetPath -Folder $parent -BaseName $cleanBase -Extension $_.Extension.ToLower() -CurrentFullName $_.FullName
    if ($_.FullName -ne $newTarget) {
        Write-Host "  [RENAME-SUB] $($_.Name) => $(Split-Path $newTarget -Leaf)" -ForegroundColor Cyan
        Rename-Item -LiteralPath $_.FullName -NewName (Split-Path $newTarget -Leaf) -ErrorAction Stop
    }
}

# Phase 3: Junk Cleanup
if ($Rules.DeleteJunkFiles) {
    Write-Host "`n--- Phase 3: Cleaning up Junk and Orphan Files ---" -ForegroundColor Yellow
    Get-ChildItem -Path $parent -File -Recurse | Where-Object {
        $_.DirectoryName -ne $parent -and ($Rules.VideoExtensions + $Rules.SubtitleExtensions) -notcontains $_.Extension.ToLower()
    } | ForEach-Object {
        Write-Host "  [DELETE] $($_.FullName)" -ForegroundColor Red
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
    
    Get-ChildItem -Path $parent -File -Recurse | Where-Object {
        $_.DirectoryName -ne $parent -and $Rules.SubtitleExtensions -contains $_.Extension.ToLower()
    } | ForEach-Object {
        Write-Host "  [DELETE-ORPHAN-SUB] $($_.FullName)" -ForegroundColor Red
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Phase 4: Empty Folder Removal
if ($Rules.DeleteEmptyFolders) {
    Write-Host "`n--- Phase 4: Removing Empty Folders ---" -ForegroundColor Yellow
    Get-ChildItem -Path $parent -Directory -Recurse | Sort-Object FullName -Descending | Where-Object { 
        -not (Get-ChildItem -LiteralPath $_.FullName -Force) 
    } | ForEach-Object {
        Write-Host "  [RMDIR] $($_.FullName)" -ForegroundColor Red
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
}

Write-Host "`n=== Engine Execution Complete ===" -ForegroundColor Cyan
