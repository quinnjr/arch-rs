# GitHub Actions Workflows

This directory contains GitHub Actions workflows for building and distributing the ArchLinux ISO.

## Workflows

### 1. `test.yml` - Comprehensive Testing Workflow

**Triggers:**
- Push to `main`, `develop`, `feature/*`, `release/*`, `hotfix/*` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

**Git Flow Integration:**
- Tests run on all branch types to catch issues early
- Required to pass before merging to `develop` or `main`

**Features:**
- **Unit Tests**: Runs the build system unit tests (`tests/build.test.sh`)
- **Validation & Linting**:
  - Validates bash script syntax
  - Checks required files exist
  - Validates package configuration
  - Validates profiledef.sh and pacman.conf
  - Checks script permissions
  - Validates Rust utility aliases configuration
- **Integration Tests**:
  - Tests build script structure
  - Validates profile directory structure
  - Checks configuration consistency
- **Test Summary**: Provides comprehensive test results summary

**Usage:**
- Automatically runs on every push and PR
- Can be manually triggered from the Actions tab
- Provides detailed test results in GitHub Actions summary

### 2. `build-iso.yml` - Full Release Workflow

**Triggers:**
- Push to version tags (e.g., `v1.0.0`) on `main` branch
- Push to `main` branch (for hotfix releases)
- Manual workflow dispatch

**Features:**
- Builds the ISO in a Docker container
- Creates GitHub releases with the ISO
- Generates SHA256 and MD5 checksums
- Uploads artifacts for 30 days
- Includes detailed release notes

**Git Flow Integration:**
- Only runs on `main` branch (production releases)
- Version tags should be created after merging `release/*` or `hotfix/*` branches
- Creates official GitHub releases

**Usage:**
```bash
# After merging release branch to main:
git checkout main
git merge --no-ff release/v1.0.0
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin main --tags

# Or trigger manually from GitHub Actions tab
```

### 3. `build-iso-simple.yml` - Simple Build Workflow

**Triggers:**
- Push to `develop`, `release/*`, `hotfix/*` branches
- Pull requests to `develop` or `main`
- Manual workflow dispatch

**Features:**
- Builds the ISO in a Docker container
- Uploads artifacts for 7 days
- Generates checksums
- No releases created (for testing/CI)

**Git Flow Integration:**
- Builds ISO for testing on `develop` branch
- Builds ISO for release candidates on `release/*` branches
- Builds ISO for hotfix testing on `hotfix/*` branches
- Artifacts can be downloaded from the Actions tab

## Requirements

- GitHub repository with Actions enabled
- Sufficient disk space (ISO builds require ~10GB)
- Docker support in GitHub Actions (available by default)

## Build Process

1. Checks out the repository
2. Sets up Docker Buildx
3. Runs ArchLinux container with archiso installed
4. Executes `./build.sh --clean`
5. Finds and processes the generated ISO
6. Uploads artifacts and/or creates release

## Artifacts

- **ISO file**: The bootable ArchLinux ISO
- **Checksums**: SHA256 and MD5 checksum files for verification

## Notes

- Builds run in privileged Docker containers (required for archiso)
- ISO files are typically 500MB-2GB in size
- Build time is approximately 10-30 minutes depending on system resources
- Artifacts are automatically cleaned up after the retention period

