# Chat History Framework Sync System

Ultra-safe project synchronization system that updates framework files while preserving your precious chat history data.

## 🎯 What This System Does

- **Tracks** all your projects using the chat history framework
- **Syncs** only framework files (CLAUDE.md, templates) across projects  
- **Preserves** all session data, daily summaries, and key concepts
- **Prevents** accidental data loss through selective updating
- **Maintains** version tracking for each project

## 🔒 Safety Guarantees

### Files That GET Updated (Framework)
- `CLAUDE.md` - Core system instructions
- `README.md` - Documentation  
- `templates/*.md` - All template files
- Framework guides and reference files

### Files That NEVER Get Touched (Data)
- `sessions/` - Your daily chat files
- `daily_summaries/` - Your end-of-day summaries  
- `key_concepts/` - Your project knowledge
- **Any actual session data is 100% safe**

## 🚀 Quick Start

### 1. Add Your First Project
```bash
./add-project.sh "My Web App" "/Users/rameshbabu/projects/webapp/docs/chat_history"
```

### 2. Add More Projects
```bash
./add-project.sh "Mobile App" "/Users/rameshbabu/projects/mobile/docs/chat_history"
./add-project.sh "API Backend" "/Users/rameshbabu/projects/api/docs/chat_history"
```

### 3. Make Framework Changes
Edit any framework files (CLAUDE.md, templates, etc.) in this directory.

### 4. Sync Changes to All Projects
```bash
./sync-all.sh
```

## 📋 Available Commands

### Core Operations
```bash
# List all registered projects
./list-projects.sh

# Add new project to registry and sync framework
./add-project.sh "Project Name" "/full/path/to/chat_history"

# Sync framework changes to all projects
./sync-all.sh

# Sync to specific project only
./sync-framework.sh project "MyProject"
```

### Advanced Operations
```bash
# Full sync script with options
./sync-framework.sh all                    # Sync all projects
./sync-framework.sh project webapp         # Sync specific project
./sync-framework.sh list                   # List projects
./sync-framework.sh --help                 # Show help
```

## 📁 Project Registry

The system tracks projects in `projects-registry.md`:

| Project Name | Path | Status | Version | Last Sync | Notes |
|--------------|------|--------|---------|-----------|-------|
| template-source | `/Users/.../deploy/docs/chat_history/` | SOURCE | v3.1 | 2025-09-11 | Master template |
| My Web App | `/Users/.../webapp/docs/chat_history` | ACTIVE | v3.1 | 2025-09-11 | |

## 🔄 Typical Workflow

### When You Improve the Framework
1. **Edit** framework files in the source directory
2. **Test** changes work correctly
3. **Run sync**: `./sync-all.sh`
4. **All projects** get the improvements instantly

### When You Start a New Project
1. **Add project**: `./add-project.sh "New Project" "/path/to/project"`
2. **Framework deployed** automatically
3. **Start using** chat history system immediately

### Monthly Maintenance
1. **Review registry**: Check for inactive projects
2. **Update versions**: After major framework changes
3. **Backup registry**: Before bulk operations

## ⚡ Example Usage Session

```bash
# Check current projects
./list-projects.sh

# Add new project
./add-project.sh "E-commerce Site" "/Users/rameshbabu/projects/ecommerce/docs/chat_history"

# Make framework improvements
vim CLAUDE.md                    # Add better instructions
vim templates/qa-entry-template.md  # Improve template

# Deploy improvements to all projects  
./sync-all.sh

# Verify specific project updated
./sync-framework.sh project "E-commerce Site"
```

## 🛡️ Error Handling

The system handles common issues gracefully:

- **Missing directories**: Creates them automatically
- **Permission errors**: Clear error messages  
- **Path not found**: Warns but continues with other projects
- **Registry corruption**: Can be rebuilt manually

## 🔧 Troubleshooting

### Project Not Syncing
```bash
# Check if project is registered
./list-projects.sh

# Add if missing
./add-project.sh "Project Name" "/correct/path"

# Try specific sync
./sync-framework.sh project "Project Name"
```

### Registry Issues
```bash
# Verify registry file
cat projects-registry.md

# Manually edit if needed
vim projects-registry.md
```

### Path Problems
```bash
# Test path exists
ls "/full/path/to/project/docs/chat_history"

# Update registry with correct path
vim projects-registry.md
```

## 📈 Benefits

### Before Sync System
- ❌ Manual copying of framework files
- ❌ Risk of overwriting session data
- ❌ Forgetting to update some projects
- ❌ Version inconsistencies across projects

### After Sync System
- ✅ One command updates all projects
- ✅ Zero risk of data loss
- ✅ Automatic framework deployment
- ✅ Complete version tracking

## 🎯 Success Metrics

**Week 1 Targets:**
- [ ] All existing projects registered  
- [ ] First successful sync completed
- [ ] Framework improvements deployed automatically

**Month 1 Targets:**
- [ ] Zero manual framework copying
- [ ] All projects stay up-to-date effortlessly
- [ ] New projects onboard in under 30 seconds

## 📝 Version History

**v3.1 (2025-09-11)**
- Enhanced CLAUDE.md with top-of-file placement rules
- Added detailed response requirements
- Exact timestamp format specifications

**v3.0 (2025-08-12)**  
- Session recovery and goal hierarchy tracking
- Interrupted session handling
- Universal project compatibility

---

**🚀 Ready to sync? Start with `./list-projects.sh` to see your current setup!**