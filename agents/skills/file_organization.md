---
name: File Organization
description: "A skill for organizing files, flattening directories, and renaming media files based on intelligent rules."
---

# File Organization Skill

This skill utilizes the `Adaptive-Folder-Organizer.ps1` engine to autonomously manage file directories.

## Capabilities
- Recursively flattening media folders.
- Stripping junk strings from filenames using regex patterns.
- Synchronizing matching subtitle (`.srt`) files with video files.
- Purging unused `.nfo`, `.txt`, and `.jpg` artifacts.

## Usage
To execute the file organization tool:
```powershell
.\Adaptive-Folder-Organizer.ps1 -Root "C:\Target\Directory"
```

## Rules Configuration
The agent can modify the `$Rules` hashtable inside the script to dynamically adapt what extensions or string patterns should be targeted.
