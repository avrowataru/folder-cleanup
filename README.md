# folder-cleanup

`folder-cleanup.ps1` is a PowerShell script for flattening messy movie folders into one clean parent folder, renaming files into a uniform format, moving only matching `.srt` subtitles, deleting junk files, and removing empty subfolders.

## Features

- Moves video files from all subfolders into one parent folder.
- Moves only the `.srt` file whose basename exactly matches the movie basename.
- Renames files into a uniform format: `Title (Year) [Resolution].ext`.
- Uses `ffprobe` locally to read actual video resolution metadata when available.
- Deletes `www.` prefixes, `[YTS.LT]`, `[YTS.MX]`, and similar release tags.
- Deletes leftover junk files in subfolders such as `.jpg`, `.png`, `.nfo`, and `.txt`.
- Deletes unmatched subtitle files left in subfolders.
- Deletes empty subfolders after cleanup.
- Logs every action to the console.

## Output format

The script normalizes movie names to this pattern:

```text
Title (Year) [Resolution].mkv
```

Examples:

```text
BEFORE: A.Single.Girl.1995.720p.BluRay.x264-[YTS.LT].mp4
AFTER:  A Single Girl (1995) [720p].mp4

BEFORE: www.5MovieRulz.report - Good Fortune (2025) 1080p WEBRip x265.mkv
AFTER:  Good Fortune (2025) [1080p].mkv
```

If `ffprobe` is not available, the script omits the resolution tag and keeps:

```text
Title (Year).ext
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Optional: `ffprobe.exe` from FFmpeg for accurate resolution tags

## ffprobe usage

The script works completely offline. If `ffprobe.exe` is available locally, it reads the real video height from the file metadata and converts it to tags like `480p`, `720p`, `1080p`, or `2160p`.

You can let the script find `ffprobe` automatically if it is in your `PATH`, or pass it explicitly:

```powershell
.\folder-cleanup.ps1 -FfprobePath "D:\Tools\ffmpeg\bin\ffprobe.exe"
```

Running from an external hard disk is fine as long as the path is correct and the drive is connected.

## How to run

```powershell
cd "D:\LIFELINE\Eng Movie"
Set-ExecutionPolicy -Scope Process Bypass
.\folder-cleanup.ps1
```

Or with explicit ffprobe path:

```powershell
.\folder-cleanup.ps1 -FfprobePath "D:\Tools\ffmpeg\bin\ffprobe.exe"
```

## What it does

### Step 1
- Recursively finds video files in subfolders.
- Reads resolution metadata with `ffprobe` if available.
- Cleans the name.
- Moves the video to the parent folder.
- Moves only the exact-match `.srt` subtitle from the same folder.

### Step 2
- Renames any already-existing `www.`-prefixed video or subtitle files in the parent folder.

### Step 3
- Deletes all non-video and non-`.srt` files left inside subfolders.

### Step 4
- Deletes leftover `.srt` files in subfolders that were not moved.

### Step 5
- Deletes empty subfolders from deepest to shallowest.

## Matching rule for subtitles

Only `.srt` files whose basename exactly matches the original video basename are moved.

Example:

```text
Movie.Name.2025.1080p.mkv
Movie.Name.2025.1080p.srt     -> moved
Movie.Name.2025.1080p.en.srt  -> not moved, later deleted
```

## Collision handling

If a target filename already exists, the script appends ` (1)`, ` (2)`, and so on.

```text
Good Fortune (2025) [1080p].mkv
Good Fortune (2025) [1080p] (1).mkv
```

## Logging tags

- `[VIDEO]` video move
- `[SUB]` subtitle move
- `[RENAME]` rename in parent folder
- `[DELETE]` file deletion
- `[RMDIR]` empty folder removal

## Notes

- The script only deletes files in subfolders, not files already in the parent folder.
- Close VLC or other media players before running it, or file locks may cause move failures.
- The script is safe to rerun; once folders are already flat, there is usually nothing left to move.
