# Adaptive Folder Organizer

`Adaptive-Folder-Organizer.ps1` is a unified, rule-based PowerShell engine for flattening messy movie folders into one clean parent folder, renaming files adaptively, moving matching subtitles, and deleting junk. It replaces previous scattered scripts with a single robust solution.

## Features

- **Rule-Based Engine**: Configure extensions and regex cleanup rules dynamically at the top of the script.
- **Adaptive Renaming**: Renames files into a uniform format: `Title (Year) [Resolution].ext`.
- **Ffprobe Integration**: Reads actual video resolution metadata when `ffprobe` is available to tag files correctly (e.g., `[1080p]`).
- **Junk and Empty Folder Deletion**: Removes leftover junk files (like `.nfo`, `.jpg`) and completely empties subfolders.
- **Subtitle Syncing**: Moves matching `.srt` subtitles alongside their respective videos.

## Documentation

- **[plan.md](./plan.md)**: Details the high-level workflow and phases of the script.
- **[syntax.md](./syntax.md)**: Explains how to modify the `$Rules` hashtable to customize the engine's behavior.

## How to Run

1. Ensure you have Windows PowerShell 5.1 or PowerShell 7+.
2. Navigate to your target folder in PowerShell:
   ```powershell
   cd "C:\path\to\your\videos"
   ```
3. Execute the script:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\Adaptive-Folder-Organizer.ps1
   ```

*If `ffprobe.exe` is not in your PATH, you can pass it explicitly:*
```powershell
.\Adaptive-Folder-Organizer.ps1 -FfprobePath "C:\Tools\ffmpeg\bin\ffprobe.exe"
```

## Legacy Scripts
The old scripts (`Folder-clean-up_final.ps1`, `Folder-clean.ps1`, `folder-cleanup-in.ps1`, `flatten-videos.ps1`) have been archived into the `temp/` directory for reference.
