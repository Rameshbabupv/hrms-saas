# Git Flow Guide - HRMS SaaS Project

## Overview

This project follows **Git Flow**, a branching model designed for release management and parallel development. This guide explains how to use Git Flow effectively in our HRMS SaaS project.

---

## Branch Structure

### Permanent Branches

#### 1. `main` (Production)
- **Purpose**: Production-ready code
- **Protected**: Yes
- **Merges from**: `release/*` and `hotfix/*` branches only
- **Direct commits**: NEVER
- **Deployment**: Automatically deploys to production
- **Tagging**: All production releases tagged (e.g., `v1.0.0`, `v1.1.0`)

#### 2. `develop` (Integration)
- **Purpose**: Integration branch for features
- **Protected**: Yes (requires PR approval)
- **Merges from**: `feature/*`, `release/*`, `hotfix/*` branches
- **Direct commits**: Avoid (use feature branches)
- **Deployment**: May deploy to staging/dev environment

### Temporary Branches

#### 3. `feature/*` (New Features)
- **Purpose**: Develop new features or enhancements
- **Naming**: `feature/short-description` or `feature/JIRA-123-description`
- **Branch from**: `develop`
- **Merge to**: `develop` (via Pull Request)
- **Lifetime**: Until feature is complete and merged
- **Examples**:
  - `feature/employee-management`
  - `feature/department-crud`
  - `feature/payroll-calculation`
  - `feature/HRMS-42-leave-approval`

#### 4. `release/*` (Release Preparation)
- **Purpose**: Prepare for production release (bug fixes, version bumps)
- **Naming**: `release/vX.Y.Z` (e.g., `release/v1.2.0`)
- **Branch from**: `develop`
- **Merge to**: `main` AND `develop`
- **Lifetime**: Until release is deployed
- **Activities**: Bug fixes, documentation updates, version updates
- **No new features**: Only fixes and release prep

#### 5. `hotfix/*` (Production Fixes)
- **Purpose**: Critical fixes for production bugs
- **Naming**: `hotfix/vX.Y.Z` or `hotfix/short-description`
- **Branch from**: `main`
- **Merge to**: `main` AND `develop`
- **Lifetime**: Until fix is deployed
- **Examples**:
  - `hotfix/v1.0.1-fix-login-bug`
  - `hotfix/critical-security-patch`

---

## Workflow Examples

### 1. Starting a New Feature

```bash
# Ensure you're on latest develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/employee-management

# Work on your feature
git add .
git commit -m "feat: add employee list component"
git push -u origin feature/employee-management

# Create Pull Request on GitHub: feature/employee-management → develop
```

### 2. Completing a Feature

```bash
# Update from develop before finishing
git checkout develop
git pull origin develop

git checkout feature/employee-management
git merge develop  # or git rebase develop

# Resolve conflicts if any
git push origin feature/employee-management

# Create Pull Request on GitHub
# After PR approval and merge, delete branch
git branch -d feature/employee-management
git push origin --delete feature/employee-management
```

### 3. Creating a Release

```bash
# Start release from develop
git checkout develop
git pull origin develop

git checkout -b release/v1.2.0

# Update version in package.json
npm version 1.2.0 --no-git-tag-version
git add package.json package-lock.json
git commit -m "chore: bump version to 1.2.0"

# Fix any last-minute bugs
git add .
git commit -m "fix: correct validation message"

# Push release branch
git push -u origin release/v1.2.0

# Create PR: release/v1.2.0 → main
# After approval, merge to main
# Then merge back to develop
```

### 4. Finalizing a Release

```bash
# After merging release/v1.2.0 → main
git checkout main
git pull origin main

# Tag the release
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0

# Merge back to develop
git checkout develop
git pull origin develop
git merge main
git push origin develop

# Delete release branch
git branch -d release/v1.2.0
git push origin --delete release/v1.2.0
```

### 5. Creating a Hotfix

```bash
# Start hotfix from main
git checkout main
git pull origin main

git checkout -b hotfix/v1.0.1-fix-auth-bug

# Fix the bug
git add .
git commit -m "fix: resolve authentication token expiry issue"

# Update version
npm version patch --no-git-tag-version
git add package.json package-lock.json
git commit -m "chore: bump version to 1.0.1"

# Push hotfix
git push -u origin hotfix/v1.0.1-fix-auth-bug

# Create PR: hotfix/v1.0.1-fix-auth-bug → main
# After merge to main, tag it
git checkout main
git pull origin main
git tag -a v1.0.1 -m "Hotfix version 1.0.1"
git push origin v1.0.1

# Merge back to develop
git checkout develop
git pull origin develop
git merge main
git push origin develop

# Delete hotfix branch
git branch -d hotfix/v1.0.1-fix-auth-bug
git push origin --delete hotfix/v1.0.1-fix-auth-bug
```

---

## Commit Message Convention

We follow **Conventional Commits** specification:

### Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, semicolons, etc.)
- **refactor**: Code refactoring (no feature change)
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Build process, tooling, dependencies
- **ci**: CI/CD configuration changes

### Examples
```bash
git commit -m "feat: add employee search functionality"
git commit -m "fix: resolve password validation error"
git commit -m "docs: update API documentation"
git commit -m "refactor: simplify authentication logic"
git commit -m "test: add unit tests for password validator"
git commit -m "chore: upgrade keycloak-js to v26.2.0"
```

### Multi-line Commit
```bash
git commit -m "feat: implement department CRUD operations

- Add department list component
- Add department form for create/edit
- Add department deletion with confirmation
- Integrate with GraphQL API

Closes #42"
```

---

## Pull Request Guidelines

### PR Title Format
Use the same format as commit messages:
```
feat: add employee management module
fix: resolve authentication bug
```

### PR Description Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Refactoring
- [ ] Performance improvement

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Tested locally
- [ ] Unit tests added/updated
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots here

## Related Issues
Closes #123
```

### PR Review Checklist
- [ ] Code follows project style guidelines
- [ ] No console.log or debugging code
- [ ] No hardcoded credentials or sensitive data
- [ ] TypeScript types properly defined
- [ ] No TypeScript errors or warnings
- [ ] Components are properly tested
- [ ] Documentation updated if needed
- [ ] No merge conflicts with target branch

---

## Version Numbering (Semantic Versioning)

We use **Semantic Versioning**: `MAJOR.MINOR.PATCH`

### Format: `vX.Y.Z`
- **MAJOR (X)**: Breaking changes, incompatible API changes
  - Example: v1.0.0 → v2.0.0
- **MINOR (Y)**: New features, backward-compatible
  - Example: v1.0.0 → v1.1.0
- **PATCH (Z)**: Bug fixes, backward-compatible
  - Example: v1.0.0 → v1.0.1

### Examples
- `v1.0.0` - Initial release
- `v1.1.0` - Added employee management feature
- `v1.1.1` - Fixed authentication bug
- `v2.0.0` - Major refactor with breaking API changes

### Updating Version
```bash
# Patch (bug fix): 1.0.0 → 1.0.1
npm version patch

# Minor (new feature): 1.0.0 → 1.1.0
npm version minor

# Major (breaking change): 1.0.0 → 2.0.0
npm version major

# Without creating git tag
npm version patch --no-git-tag-version
```

---

## Branch Protection Rules

### `main` Branch
- ✅ Require pull request reviews (at least 1 approval)
- ✅ Require status checks to pass (tests, build)
- ✅ Require branches to be up to date before merging
- ✅ Include administrators
- ✅ Restrict who can push to matching branches
- ✅ Do not allow force push
- ✅ Do not allow deletions

### `develop` Branch
- ✅ Require pull request reviews (at least 1 approval)
- ✅ Require status checks to pass
- ✅ Require branches to be up to date before merging
- ⚠️ Allow administrators to bypass
- ✅ Do not allow force push
- ✅ Do not allow deletions

---

## Quick Reference Commands

### Check Current Branch
```bash
git branch  # Local branches
git branch -a  # All branches (local + remote)
```

### Switch Branches
```bash
git checkout develop
git checkout -b feature/new-feature  # Create and switch
```

### Update Branch
```bash
git pull origin develop
git fetch origin  # Fetch without merge
```

### Delete Branches
```bash
git branch -d feature/old-feature  # Local delete
git push origin --delete feature/old-feature  # Remote delete
```

### View Git Flow Structure
```bash
git log --graph --oneline --all --decorate
```

### Check for Uncommitted Changes
```bash
git status
git diff  # See changes
```

---

## Common Scenarios

### Scenario 1: Feature Conflicts with Develop
```bash
# Option 1: Merge develop into feature
git checkout feature/my-feature
git merge develop
# Resolve conflicts, commit, push

# Option 2: Rebase feature on develop (cleaner history)
git checkout feature/my-feature
git rebase develop
# Resolve conflicts, continue rebase
git rebase --continue
git push --force-with-lease origin feature/my-feature
```

### Scenario 2: Need to Fix Bug While Working on Feature
```bash
# Stash current work
git stash save "WIP: my feature work"

# Create bugfix branch
git checkout develop
git checkout -b feature/fix-critical-bug

# Fix bug, commit, push, create PR
# After PR merged, return to feature
git checkout feature/my-feature
git stash pop
```

### Scenario 3: Accidentally Committed to Wrong Branch
```bash
# If not pushed yet
git reset HEAD~1  # Undo last commit, keep changes
git stash  # Stash changes
git checkout correct-branch
git stash pop  # Apply changes
```

### Scenario 4: Need to Undo Last Commit
```bash
# Undo commit but keep changes
git reset --soft HEAD~1

# Undo commit and discard changes (DANGEROUS!)
git reset --hard HEAD~1
```

---

## Git Flow Visualization

```
main        →  [v1.0.0] ────────────────→ [v1.1.0] ───→ [v1.1.1]
                  ↑                          ↑            ↑
                  │                          │            │
release/*         │                     [v1.1.0] ────→    │
                  │                        ↑ │            │
                  │                        │ │            │
develop     ─────┴─→ feat1 → feat2 → feat3┘ └───→ feat4  │
                      ↓       ↓       ↓              ↓    │
feature/*         [F1]     [F2]     [F3]          [F4]    │
                                                           │
hotfix/*                                              [H1] ┘
```

### Legend
- `main`: Production code
- `develop`: Integration branch
- `feature/*`: New features
- `release/*`: Release preparation
- `hotfix/*`: Production bug fixes

---

## Best Practices

### DO ✅
- ✅ Create feature branches from `develop`
- ✅ Use descriptive branch names
- ✅ Write meaningful commit messages
- ✅ Keep commits small and focused
- ✅ Pull latest changes before starting work
- ✅ Test thoroughly before creating PR
- ✅ Resolve conflicts before requesting review
- ✅ Delete branches after merging
- ✅ Tag releases on `main`
- ✅ Keep `develop` and `main` clean

### DON'T ❌
- ❌ Commit directly to `main` or `develop`
- ❌ Force push to shared branches
- ❌ Create features from other features
- ❌ Leave unfinished features in `develop`
- ❌ Skip code reviews
- ❌ Commit large files or secrets
- ❌ Use generic commit messages ("fix", "update")
- ❌ Merge without testing
- ❌ Keep stale branches around
- ❌ Mix multiple features in one branch

---

## Troubleshooting

### Problem: Merge Conflicts
```bash
# See conflicting files
git status

# Open files, resolve conflicts (look for <<<<<<, ======, >>>>>>)
# After resolving
git add .
git commit -m "chore: resolve merge conflicts"
git push
```

### Problem: Accidentally Modified Wrong File
```bash
# Discard changes to specific file
git checkout -- path/to/file

# Discard all uncommitted changes (DANGEROUS!)
git reset --hard HEAD
```

### Problem: Need to Sync Fork with Upstream
```bash
# Add upstream remote (one time)
git remote add upstream https://github.com/original/repo.git

# Sync with upstream
git fetch upstream
git checkout develop
git merge upstream/develop
git push origin develop
```

---

## CI/CD Integration

### GitHub Actions Workflows
- **On PR to `develop`**: Run tests, linting, build
- **On merge to `develop`**: Deploy to staging
- **On merge to `main`**: Deploy to production
- **On tag creation**: Create GitHub release

### Example Workflow Triggers
```yaml
# Run tests on feature branches
on:
  pull_request:
    branches: [ develop ]

# Deploy to staging
on:
  push:
    branches: [ develop ]

# Deploy to production
on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
```

---

## Resources

### Git Flow Tools
- **git-flow**: Git extension for Git Flow commands
  ```bash
  # Install (macOS)
  brew install git-flow

  # Initialize
  git flow init

  # Start feature
  git flow feature start my-feature

  # Finish feature
  git flow feature finish my-feature
  ```

### Useful Links
- [Git Flow Original Article](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Flow Guide](https://docs.github.com/en/get-started/quickstart/github-flow)

---

## Quick Start Checklist

For new developers joining the project:

- [ ] Clone repository
- [ ] Set up develop branch: `git checkout develop`
- [ ] Read this Git Flow guide
- [ ] Configure git user: `git config user.name` and `git config user.email`
- [ ] Install git-flow (optional): `brew install git-flow`
- [ ] Create your first feature branch: `git checkout -b feature/my-first-feature`
- [ ] Make changes, commit, push
- [ ] Create your first Pull Request
- [ ] Ask for code review

---

## Contact

For questions about Git Flow in this project, contact:
- **Team Lead**: [Name]
- **DevOps**: [Name]
- **Slack Channel**: #hrms-saas-dev

---

**Last Updated**: 2025-01-04
**Version**: 1.0.0
