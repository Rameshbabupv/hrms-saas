# Git Flow Helper Scripts

This directory contains helper scripts to simplify Git Flow operations.

## Available Scripts

### 1. `git-flow-feature.sh` - Feature Management

Manage feature branches easily.

**Commands:**
```bash
# Start a new feature
./scripts/git-flow-feature.sh start employee-management

# Finish a feature (after PR merged)
./scripts/git-flow-feature.sh finish employee-management

# List all features
./scripts/git-flow-feature.sh list
```

**What it does:**
- **Start**: Creates feature branch from develop, pushes to remote
- **Finish**: Deletes local and remote feature branch after merge
- **List**: Shows all local and remote feature branches

---

### 2. `git-flow-release.sh` - Release Management

Manage release branches and versions.

**Commands:**
```bash
# Start a new release
./scripts/git-flow-release.sh start 1.2.0

# Finish a release (after PR merged to main)
./scripts/git-flow-release.sh finish 1.2.0

# List releases and tags
./scripts/git-flow-release.sh list
```

**What it does:**
- **Start**: Creates release branch, bumps version in package.json, pushes to remote
- **Finish**: Creates git tag, merges back to develop, cleans up release branch
- **List**: Shows all release branches and recent tags

---

### 3. `git-flow-hotfix.sh` - Hotfix Management

Manage hotfix branches for production bugs.

**Commands:**
```bash
# Start a new hotfix
./scripts/git-flow-hotfix.sh start 1.0.1
# or with descriptive name
./scripts/git-flow-hotfix.sh start fix-auth-bug

# Finish a hotfix (after PR merged to main)
./scripts/git-flow-hotfix.sh finish 1.0.1

# List hotfixes
./scripts/git-flow-hotfix.sh list
```

**What it does:**
- **Start**: Creates hotfix branch from main, pushes to remote
- **Finish**: Creates git tag, merges back to develop, cleans up hotfix branch
- **List**: Shows all hotfix branches

---

## Workflow Examples

### Feature Development Workflow

```bash
# 1. Start feature
./scripts/git-flow-feature.sh start user-profile

# 2. Make changes
git add .
git commit -m "feat: add user profile page"
git push

# 3. Create PR on GitHub: feature/user-profile → develop

# 4. After PR approved and merged, finish feature
./scripts/git-flow-feature.sh finish user-profile
```

---

### Release Workflow

```bash
# 1. Start release
./scripts/git-flow-release.sh start 1.2.0

# 2. Fix any bugs, update docs
git add .
git commit -m "fix: correct validation message"
git push

# 3. Create PR on GitHub: release/v1.2.0 → main

# 4. After PR merged to main, finish release
./scripts/git-flow-release.sh finish 1.2.0
```

---

### Hotfix Workflow

```bash
# 1. Start hotfix
./scripts/git-flow-hotfix.sh start 1.0.1

# 2. Fix the bug
git add .
git commit -m "fix: resolve authentication token expiry"

# 3. Bump version
npm version patch --no-git-tag-version
git add package.json package-lock.json
git commit -m "chore: bump version to 1.0.1"
git push

# 4. Create PR on GitHub: hotfix/1.0.1 → main

# 5. After PR merged, finish hotfix
./scripts/git-flow-hotfix.sh finish 1.0.1
```

---

## Requirements

- Git installed
- Node.js and npm installed (for version bumping)
- Bash shell (available on macOS/Linux, use Git Bash on Windows)

---

## Troubleshooting

### Script Permission Denied

```bash
chmod +x scripts/git-flow-feature.sh
chmod +x scripts/git-flow-release.sh
chmod +x scripts/git-flow-hotfix.sh
```

### Branch Already Exists

Delete the branch first:
```bash
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

### Merge Conflicts

Resolve conflicts manually:
```bash
git status  # See conflicting files
# Edit files to resolve conflicts
git add .
git commit -m "chore: resolve merge conflicts"
git push
```

---

## Benefits of Using Scripts

✅ **Consistency**: Everyone follows the same workflow
✅ **Automation**: Reduces manual steps and errors
✅ **Best Practices**: Enforces Git Flow conventions
✅ **Time Saving**: Quick commands for common operations
✅ **Beginner Friendly**: Clear instructions and error messages

---

## Alternative: Manual Git Flow

If you prefer manual commands, see `GIT_FLOW_GUIDE.md` for detailed instructions.

You can also install `git-flow` tool:
```bash
brew install git-flow
git flow init
```

---

## Script Features

- ✅ Color-coded output for better readability
- ✅ Error handling and validation
- ✅ Usage instructions with examples
- ✅ Automatic branch switching and pulling
- ✅ Remote push/delete operations
- ✅ Version validation (for releases)
- ✅ Helpful next-step instructions

---

## Contributing

If you find bugs or want to improve these scripts, please:
1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Create a Pull Request

---

**Last Updated**: 2025-01-04
