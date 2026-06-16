# Project Memory

## Current State
- The legacy `folder-cleanup` PowerShell scripts (`Folder-clean-up_final.ps1`, `Folder-clean.ps1`, `folder-cleanup-in.ps1`, `flatten-videos.ps1`) have been safely relocated to the `temp/` folder.
- A single, unified `Adaptive-Folder-Organizer.ps1` script has been successfully created. This new engine uses a rule-based hashtable to intelligently handle videos, subtitles, empty folders, and junk files.
- Documentation including `README.md`, `plan.md`, and `syntax.md` have been generated and updated to reflect the new adaptive script.
- Agent skill templates (`file_organization.md` and `deep_agents_memory.md`) have been initialized in `agents/skills/`.
- **UPDATE**: The core `Get-CleanBaseName` logic and `$Rules` have been optimized within the new `Adaptive-Folder-Organizer.ps1` to correctly parse hyphens without breaking names like "Pre-Wedding", and dynamically match trailing or leading domain string prefixes safely without greedy truncation.

## Tasks Completed
- [x] Consolidate folder cleanup logic into one script.
- [x] Create an adaptive, rule-based configuration engine within the script.
- [x] Relocate legacy files to `temp/`.
- [x] Scaffold `plan.md` and `syntax.md`.
- [x] Refresh `README.md`.
- [x] Introduce `file_organization` and `deep_agents_memory` skill representations.
- [x] Refine Regex in the unified script to prevent aggressive truncation (e.g., preserve internal hyphens like "Pre-Wedding").

## TODO / Next Assignment
- Test the `Adaptive-Folder-Organizer.ps1` on a live directory with messy file names to fine-tune the regex patterns in `$Rules.CleanupPatterns`.
- If new file extensions (e.g., audio files, specific document types) need to be filtered or retained, update the `$Rules` hashtable accordingly.
- Expand `file_organization.md` skill to integrate with `npx` properly if this tool is deployed to an environment where the agent wrapper supports standard `npx skills` execution.
