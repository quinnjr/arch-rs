# Git Flow Branching Model

This repository follows the [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) branching model.

## Branch Structure

### Main Branches

- **`main`** - Production branch
  - Always stable and deployable
  - Only updated via releases or hotfixes
  - Protected branch (requires PR and reviews)

- **`develop`** - Development integration branch
  - Integration branch for features
  - Always in a deployable state
  - Source for release branches

### Supporting Branches

- **`feature/*`** - Feature branches
  - Branch from: `develop`
  - Merge back to: `develop`
  - Naming: `feature/description` (e.g., `feature/add-new-utility`)
  - Delete after merge

- **`release/*`** - Release preparation branches
  - Branch from: `develop`
  - Merge back to: `main` and `develop`
  - Naming: `release/v1.0.0` (version number)
  - Used for final testing and bug fixes before release
  - Delete after merge

- **`hotfix/*`** - Hotfix branches
  - Branch from: `main`
  - Merge back to: `main` and `develop`
  - Naming: `hotfix/description` (e.g., `hotfix/critical-bug`)
  - For urgent production fixes
  - Delete after merge

## Workflow

### Starting a Feature

```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-new-feature
# ... make changes ...
git commit -m "Add feature: description"
git push origin feature/my-new-feature
```

### Finishing a Feature

```bash
# Create pull request from feature/* to develop
# After PR is approved and merged:
git checkout develop
git pull origin develop
git branch -d feature/my-new-feature  # Delete local branch
```

### Starting a Release

```bash
git checkout develop
git pull origin develop
git checkout -b release/v1.0.0
# ... final testing and bug fixes ...
git commit -m "Prepare release v1.0.0"
```

### Finishing a Release

```bash
# Merge release branch to main
git checkout main
git merge --no-ff release/v1.0.0
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin main --tags

# Merge release branch to develop
git checkout develop
git merge --no-ff release/v1.0.0
git push origin develop

# Delete release branch
git branch -d release/v1.0.0
git push origin --delete release/v1.0.0
```

### Starting a Hotfix

```bash
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug
# ... fix the bug ...
git commit -m "Fix: critical bug description"
```

### Finishing a Hotfix

```bash
# Merge hotfix to main
git checkout main
git merge --no-ff hotfix/critical-bug
git tag -a v1.0.1 -m "Hotfix: critical bug"
git push origin main --tags

# Merge hotfix to develop
git checkout develop
git merge --no-ff hotfix/critical-bug
git push origin develop

# Delete hotfix branch
git branch -d hotfix/critical-bug
git push origin --delete hotfix/critical-bug
```

## CI/CD Behavior

### Tests
- Run on all branches (feature, release, hotfix, develop, main)
- Required to pass before merging

### Builds
- **Feature branches**: No builds (testing only)
- **Release branches**: Build ISO for testing
- **Hotfix branches**: Build ISO for testing
- **develop branch**: Build ISO as artifact (not released)
- **main branch**: Only builds on tags (creates GitHub release)

### Releases
- Only created when version tags are pushed to `main`
- Format: `v*.*.*` (e.g., `v1.0.0`)

## Best Practices

1. **Always branch from the correct base**
   - Features: from `develop`
   - Releases: from `develop`
   - Hotfixes: from `main`

2. **Keep branches focused**
   - One feature per feature branch
   - One release per release branch
   - One fix per hotfix branch

3. **Use descriptive branch names**
   - `feature/add-ripgrep-support`
   - `release/v1.2.0`
   - `hotfix/fix-iso-boot-issue`

4. **Keep commits atomic**
   - One logical change per commit
   - Write clear commit messages

5. **Test before merging**
   - All tests must pass
   - Code review required for develop/main

6. **Delete merged branches**
   - Clean up after successful merge
   - Keeps repository tidy

## Branch Protection Rules

### main
- Require pull request reviews
- Require status checks to pass
- Require branches to be up to date
- No force pushes
- No deletion

### develop
- Require pull request reviews
- Require status checks to pass
- No force pushes

