# Rule Engine Syntax Guide

The `Adaptive-Folder-Organizer.ps1` runs on a `$Rules` hashtable located at the top of the script. This serves as the brain of the rule-based engine.

## The `$Rules` Object

```powershell
$Rules = @{
    VideoExtensions    = @('.mkv', '.mp4', '.avi', '.mov', '.wmv', '.m4v')
    SubtitleExtensions = @('.srt', '.sub', '.ass')
    JunkExtensions     = @('.nfo', '.txt', '.jpg', '.png', '.url', '.exe', '.zip', '.rar')
    DeleteJunkFiles    = $true
    DeleteEmptyFolders = $true
    CleanupPatterns    = @(
        '^www\.[^\s]+\s*-\s*',
        '\s*\[[^\]]*\]',
        '(?i)\b(720p|1080p|2160p|4k|bluray|webrip|web-dl|hdrip|x264|x265|hevc|avc|aac|dd5\.1|10bit|yts\.\w+|exyusubs)\b',
        '[._-]+'
    )
}
```

## How to Customize

- **Adding New Formats**: Simply add `.newext` to `VideoExtensions` or `SubtitleExtensions`.
- **Prevent Deletions**: Change `DeleteJunkFiles` or `DeleteEmptyFolders` to `$false` if you want a dry-run or manual cleanup.
- **Cleanup Patterns**: Add regular expressions to `CleanupPatterns`. They are executed in order.
  - E.g., `'\s*\[[^\]]*\]'` removes anything inside brackets `[]`.
  - The regex `[._-]+` replaces underscores, dots, and hyphens with spaces.

## Renaming Logic

The `Get-CleanBaseName` function processes names based on `CleanupPatterns`. It isolates the "Title" and "(Year)" from standard scene release formats and injects an optional `[Resolution]` tag parsed dynamically via `ffprobe`.
