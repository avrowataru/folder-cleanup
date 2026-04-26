param(
    [string]$Root = (Get-Location).Path
)

$videoExts = @('.mkv', '.mp4', '.avi', '.mov', '.wmv', '.m4v')
$subExts   = @('.srt', '.ass', '.ssa', '.sub')
$parent    = (Resolve-Path $Root).Path

Write-Host "=== Starting Flatten Script ===" -ForegroundColor Cyan
Write-Host "Working folder: $parent"
Write-Host ""

function Get-CleanBaseName {
    param([string]$BaseName)

    $name = $BaseName

    # Remove leading www. site prefix like "www.5MovieRulz.report - "
    $name = $name -replace '^www\.[^\s]+\s*-\s*', ''

    # Keep only "Title (Year)" and strip everything after
    $name = $name -replace '^(.+?\(\d{4}\)).*$', '$1'

    # Remove bracketed tags like [YTS.LT] [BluRay] [x264] etc.
    $name = $name -replace '\s*\[[^\]]*\]', ''

    # Remove dot-separated technical tags like 720p, BluRay, x264, WEBRip, HEVC etc.
    $name = $name -replace '\s*(720p|1080p|2160p|4K|BluRay|WEBRip|WEB-DL|HDRip|x264|x265|HEVC|AVC|AAC|DD5\.1|YTS\.\w+)(\s|$)', ' '

    # Clean trailing/leading junk
    $name = $name.Trim(' ', '.', '-', '_')

    if ([string]::IsNullOrWhiteSpace($name)) { $name = $BaseName.Trim() }
    return $name
}

function Get-UniqueTargetPath {
    param(
        [string]$Folder,
        [string]$BaseName,
        [string]$Extension
    )

    $candidate = Join-Path $Folder ($BaseName + $Extension)
    $i = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Folder ("{0} ({1}){2}" -f $BaseName, $i, $Extension)
        $i++
    }
    return $candidate
}

# --- Step 1: Move and rename video + matching srt files into parent folder ---

Write-Host "--- Step 1: Moving video and subtitle files ---" -ForegroundColor Yellow

$videos = Get-ChildItem -Path $parent -File -Recurse | Where-Object {
    $_.DirectoryName -ne $parent -and $videoExts -contains $_.Extension.ToLower()
} | Sort-Object FullName

if ($videos.Count -eq 0) {
    Write-Host "  No video files found in subfolders." -ForegroundColor Gray
} else {
    foreach ($video in $videos) {
        $cleanBase   = Get-CleanBaseName -BaseName $video.BaseName
        $videoTarget = Get-UniqueTargetPath -Folder $parent -BaseName $cleanBase -Extension $video.Extension.ToLower()

        $sourceDir         = $video.DirectoryName
        $originalVideoBase = $video.BaseName
        $finalVideoBase    = [System.IO.Path]::GetFileNameWithoutExtension($videoTarget)

        Write-Host "  [VIDEO] Moving:" -ForegroundColor Green
        Write-Host "    FROM: $($video.FullName)"
        Write-Host "    TO:   $videoTarget"

        Move-Item -LiteralPath $video.FullName -Destination $videoTarget -ErrorAction Stop

        # Move ONLY the subtitle file whose BaseName exactly matches the video BaseName
        Get-ChildItem -Path $sourceDir -File | Where-Object {
            $subExts -contains $_.Extension.ToLower() -and
            $_.BaseName -eq $originalVideoBase
        } | ForEach-Object {
            $subTarget = Get-UniqueTargetPath -Folder $parent -BaseName $finalVideoBase -Extension $_.Extension.ToLower()
            Write-Host "  [SUB]   Moving:" -ForegroundColor Cyan
            Write-Host "    FROM: $($_.FullName)"
            Write-Host "    TO:   $subTarget"
            Move-Item -LiteralPath $_.FullName -Destination $subTarget -ErrorAction Stop
        }
    }
}

Write-Host ""

# --- Step 2: Clean www. prefix from files already sitting in the parent ---

Write-Host "--- Step 2: Renaming leftover www. prefixed files in parent ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -File | Where-Object {
    ($videoExts + $subExts) -contains $_.Extension.ToLower() -and
    $_.Name -match '^www\.'
} | ForEach-Object {
    $cleanBase = Get-CleanBaseName -BaseName $_.BaseName
    $newTarget = Get-UniqueTargetPath -Folder $parent -BaseName $cleanBase -Extension $_.Extension.ToLower()
    if ($_.FullName -ne $newTarget) {
        Write-Host "  [RENAME] $($_.Name) => $(Split-Path $newTarget -Leaf)" -ForegroundColor Green
        Rename-Item -LiteralPath $_.FullName -NewName (Split-Path $newTarget -Leaf) -ErrorAction Stop
    }
}

Write-Host ""

# --- Step 3: Delete all non-video, non-subtitle files in subfolders (images, nfo, txt, jpg etc.) ---

Write-Host "--- Step 3: Deleting leftover junk files in subfolders ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -File -Recurse | Where-Object {
    $_.DirectoryName -ne $parent -and
    ($videoExts + $subExts) -notcontains $_.Extension.ToLower()
} | ForEach-Object {
    Write-Host "  [DELETE] $($_.FullName)" -ForegroundColor Red
    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
}

Write-Host ""

# --- Step 4: Delete any leftover subtitle files in subfolders ---

Write-Host "--- Step 4: Deleting leftover subtitle files in subfolders ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -File -Recurse | Where-Object {
    $_.DirectoryName -ne $parent -and
    $subExts -contains $_.Extension.ToLower()
} | ForEach-Object {
    Write-Host "  [DELETE] $($_.FullName)" -ForegroundColor Red
    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
}

Write-Host ""

# --- Step 5: Delete now-empty subfolders ---

Write-Host "--- Step 5: Deleting empty subfolders ---" -ForegroundColor Yellow

Get-ChildItem -Path $parent -Directory -Recurse |
    Sort-Object FullName -Descending |
    Where-Object {
        -not (Get-ChildItem -LiteralPath $_.FullName -Force)
    } |
    ForEach-Object {
        Write-Host "  [RMDIR] $($_.FullName)" -ForegroundColor Red
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan