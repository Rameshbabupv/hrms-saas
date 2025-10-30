# Chat History Framework - Project Registry

This file tracks all projects using the chat history framework for selective synchronization.

## Framework Version
**Current Version:** v3.1 (2025-09-11)
**Last Update:** Enhanced with top-of-file placement and detailed response requirements

## Registered Projects

| Project Name | Path | Status | Version | Last Sync | Notes |
|--------------|------|--------|---------|-----------|-------|
| template-source | `/Users/rameshbabu/data/projects/personnel/deploy/docs/chat_history/` | SOURCE | v3.1 | 2025-09-11 | Master template |
| | | | | | |
| | | | | | |
| | | | | | |

## Project Status Legend
- **SOURCE** - Master template (this location)
- **ACTIVE** - Framework deployed and in use
- **INACTIVE** - Framework deployed but not currently used
- **NEEDS_SYNC** - Framework files out of date
- **DATA_ONLY** - Contains session data but framework outdated

## Adding New Projects

To register a new project:
1. Copy framework to project: `cp -r chat_history/ /path/to/project/docs/`
2. Add entry to table above with:
   - Project name
   - Full path to chat_history directory
   - Status: ACTIVE
   - Current version: v3.1
   - Today's date
3. Verify CLAUDE.md integration in main project file

## Framework Files vs Data Files

### Framework Files (Safe to Sync/Overwrite)
- `CLAUDE.md` - Core system instructions
- `README.md` - Documentation
- `Framework-Portability-Guide.md` - Technical guide
- `System_Prompt.md` - System recreation guide
- `action_items.md` - Template file
- `templates/` - All template files
  - `morning-startup-routine.md`
  - `interrupted-session-recovery.md`
  - `end-of-day-ceremony.md`
  - `qa-entry-template.md`
  - `qa-entry-template-quick.md`
  - `daily-summary-template.md`
  - `daily-summary-template-quick.md`
  - `session-template.md`
  - `concept-template.md`
  - `action-item-template.md`

### Data Files (NEVER Overwrite)
- `sessions/` - All session files
- `daily_summaries/` - All summary files
- `key_concepts/` - All concept files
- Any actual `.md` files with session data

## Sync Commands

### Quick Add Project
```bash
# From the source directory
./add-project.sh "ProjectName" "/full/path/to/project/docs/chat_history"
```

### Sync All Projects
```bash
# Update framework files across all registered projects
./sync-all-projects.sh
```

### Sync Single Project  
```bash
# Update specific project
./sync-project.sh "ProjectName"
```

## Maintenance Notes

- Review registry monthly for inactive projects
- Update version numbers after framework changes
- Test sync process before deploying major updates
- Backup registry file when making bulk changes

| Resume Project | `/Users/rameshbabu/data/projects/personnel/resumes/docs/chat_history` | ACTIVE | v3.1 | 2025-09-11 | |
