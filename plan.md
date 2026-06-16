# Folder Organizer Execution Plan

The `Adaptive-Folder-Organizer.ps1` script is a unified rule-based engine designed to autonomously organize movie and video files.

## High-Level Workflow

1. **Initialization**: The script reads the inline rule engine configuration. The rules define what file extensions are treated as videos (`.mp4`, `.mkv`), subtitles (`.srt`), and junk (`.nfo`, `.txt`, `.url`). It also loads regex cleanup patterns.
2. **Metadata Extraction (Optional)**: If `ffprobe` is found locally, the script hooks into it to parse out the video height to tag the file correctly (e.g. `[1080p]`, `[2160p]`).
3. **Phase 1 (Flatten & Organize)**: The engine recursively iterates through the target folder's subdirectories. It matches videos, extracts metadata, standardizes the filename using regex, moves it to the parent directory, and then searches the same subdirectory for exactly matching subtitles, moving them alongside the video.
4. **Phase 2 (Orphan Subtitles)**: Subtitles already in the parent directory that were downloaded separately are parsed and renamed to match the standard format.
5. **Phase 3 (Junk Cleanup)**: Based on the rule configuration, extraneous junk files (images, release notes) are forcibly deleted. Additionally, leftover `.srt` files in subdirectories (which didn't match the original video name) are cleaned up.
6. **Phase 4 (Empty Folder Removal)**: Any folders that are now completely empty as a result of the moves and deletes are purged recursively.
