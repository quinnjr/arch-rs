#!/usr/bin/env bash
# Run all CI/CD tests locally to debug issues
# This script replicates the GitHub Actions workflow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

FAILED=0

# Job 1: Unit Tests
log_info "=== Running Unit Tests ==="
if bash tests/build.test.sh; then
    log_info "✓ Unit tests passed"
else
    log_error "✗ Unit tests failed"
    FAILED=1
fi
echo ""

# Job 2: Validation & Linting
log_info "=== Running Validation & Linting ==="

# Validate script syntax
log_info "Validating bash script syntax..."
SYNTAX_FAILED=0
while IFS= read -r -d '' script; do
    if ! bash -n "$script" 2>&1; then
        log_error "Syntax error in: $script"
        SYNTAX_FAILED=1
    else
        log_info "✓ $script"
    fi
done < <(find . -name "*.sh" -type f ! -path "./.git/*" ! -path "./work/*" ! -path "./out/*" ! -path "./build/*" -print0)

if [ $SYNTAX_FAILED -eq 1 ]; then
    log_error "Script syntax validation failed"
    FAILED=1
else
    log_info "✓ All scripts have valid syntax"
fi

# Check required files
log_info "Checking required files..."
REQUIRED_FILES=(
    "build.sh"
    "profile/packages.x86_64"
    "profile/pacman.conf"
    "profile/profiledef.sh"
    "profile/airootfs/root/customize_airootfs.sh"
    "profile/airootfs/root/post-install.sh"
    "profile/airootfs/root/.automated_script.sh"
    "profile/airootfs/root/install-helper.sh"
)

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Required file missing: $file"
        MISSING=1
    else
        log_info "✓ $file"
    fi
done

if [ $MISSING -eq 1 ]; then
    log_error "Required files check failed"
    FAILED=1
else
    log_info "✓ All required files present"
fi

# Validate package configuration
log_info "Validating package configuration..."
if ! grep -q "uutils-coreutils" profile/packages.x86_64; then
    log_error "uutils-coreutils not found in packages.x86_64"
    FAILED=1
else
    log_info "✓ uutils-coreutils in package list"
fi

if grep -q "^coreutils$" profile/packages.x86_64; then
    log_error "GNU coreutils should not be in packages.x86_64"
    FAILED=1
else
    log_info "✓ GNU coreutils not in package list"
fi

RUST_UTILS=("ripgrep" "fd" "bat" "eza" "procs" "bottom" "dust" "zoxide" "starship" "tealdeer" "sd" "tokei" "hyperfine")
MISSING_UTILS=0
for util in "${RUST_UTILS[@]}"; do
    if ! grep -q "^${util}" profile/packages.x86_64; then
        log_warn "Warning: $util not found in packages.x86_64"
        MISSING_UTILS=1
    fi
done

if [ $MISSING_UTILS -eq 1 ]; then
    log_warn "Some Rust utilities may be missing from package list"
else
    log_info "✓ All Rust utilities in package list"
fi

# Validate profiledef.sh
log_info "Validating profiledef.sh..."
# Check that pacman_packages_exclude is empty or commented out
# We allow GNU utilities during build and remove them in customize_airootfs.sh
if grep -A 5 "pacman_packages_exclude=(" profile/profiledef.sh | grep -qE "^[[:space:]]*coreutils"; then
    log_warn "Warning: coreutils in pacman_packages_exclude (should be empty/commented)"
else
    log_info "✓ pacman_packages_exclude is empty/commented (correct - allows build)"
fi

# Validate pacman.conf
log_info "Validating pacman.conf..."
# Check that IgnorePkg is commented out or not present
# We allow GNU utilities during build and remove them in customize_airootfs.sh
if grep -q "^IgnorePkg.*coreutils" profile/pacman.conf; then
    log_error "IgnorePkg contains coreutils (should be commented out)"
    log_error "This prevents package installation. GNU utilities are removed in customize_airootfs.sh instead."
    FAILED=1
else
    log_info "✓ IgnorePkg is commented out or not present (correct - allows build)"
fi

# Verify that customize_airootfs.sh handles GNU utility removal
if grep -q "Removing GNU utilities" profile/airootfs/root/customize_airootfs.sh; then
    log_info "✓ customize_airootfs.sh handles GNU utility removal"
else
    log_warn "Warning: customize_airootfs.sh may not handle GNU utility removal"
fi

# Note: We no longer check for individual packages in IgnorePkg
# since we allow GNU utilities during build and remove them in customize_airootfs.sh

# Check script permissions
log_info "Checking script permissions..."
SCRIPTS=(
    "build.sh"
    "profile/airootfs/root/customize_airootfs.sh"
    "profile/airootfs/root/post-install.sh"
    "profile/airootfs/root/.automated_script.sh"
    "profile/airootfs/root/install-helper.sh"
    "tests/build.test.sh"
)

PERM_FAILED=0
for script in "${SCRIPTS[@]}"; do
    if [ ! -x "$script" ]; then
        log_error "Script not executable: $script"
        PERM_FAILED=1
    else
        log_info "✓ $script is executable"
    fi
done

if [ $PERM_FAILED -eq 1 ]; then
    log_error "Script permissions check failed"
    FAILED=1
fi

# Validate aliases configuration
log_info "Validating Rust utility aliases..."
if ! grep -q "rust-utils.sh" profile/airootfs/root/customize_airootfs.sh; then
    log_error "rust-utils.sh not created in customize_airootfs.sh"
    FAILED=1
else
    log_info "✓ rust-utils.sh configured"
fi

if grep "alias ls=" profile/airootfs/root/customize_airootfs.sh | grep -q "eza"; then
    log_info "✓ eza aliased to ls"
else
    log_warn "Warning: eza may not be aliased to ls"
fi

if ! grep -q "create_rust_wrapper.*ls.*eza" profile/airootfs/root/customize_airootfs.sh; then
    log_warn "Warning: ls wrapper for eza may not be created"
else
    log_info "✓ ls wrapper for eza configured"
fi

echo ""

# Job 3: Integration Tests
log_info "=== Running Integration Tests ==="

# Test build script structure
log_info "Testing build script structure..."
if [ ! -x "build.sh" ]; then
    log_error "build.sh is not executable"
    FAILED=1
else
    log_info "✓ build.sh is executable"
fi

if ! grep -q "log_info\|log_error" build.sh; then
    log_warn "Warning: build.sh may be missing logging functions"
else
    log_info "✓ build.sh has logging functions"
fi

if ! grep -q "EUID\|root" build.sh; then
    log_warn "Warning: build.sh may not check for root privileges"
else
    log_info "✓ build.sh checks for root privileges"
fi

# Test profile structure
log_info "Testing profile structure..."
PROFILE_DIRS=(
    "profile"
    "profile/airootfs"
    "profile/airootfs/etc"
    "profile/airootfs/root"
    "profile/efiboot"
    "profile/syslinux"
)

PROFILE_FAILED=0
for dir in "${PROFILE_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        log_error "Directory missing: $dir"
        PROFILE_FAILED=1
    else
        log_info "✓ $dir"
    fi
done

if [ $PROFILE_FAILED -eq 1 ]; then
    log_error "Profile structure check failed"
    FAILED=1
else
    log_info "✓ Profile directory structure valid"
fi

# Test configuration consistency
log_info "Testing configuration consistency..."
EXCLUDED_PROFILEDEF=$(grep -A 10 "pacman_packages_exclude=(" profile/profiledef.sh | grep -oE '[a-z-]+' | grep -v "pacman_packages_exclude" | sort)
EXCLUDED_PACMAN=$(grep "^IgnorePkg" profile/pacman.conf | grep -oE '[a-z-]+' | grep -v "IgnorePkg" | sort)

if [ -z "$EXCLUDED_PROFILEDEF" ] || [ -z "$EXCLUDED_PACMAN" ]; then
    log_warn "Warning: Exclusion lists may be empty"
else
    log_info "✓ Exclusion lists present in both files"
fi

echo ""
log_info "=== Test Summary ==="
if [ $FAILED -eq 0 ]; then
    log_info "✓ All tests passed!"
    exit 0
else
    log_error "✗ Some tests failed"
    exit 1
fi

