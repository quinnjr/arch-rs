#!/usr/bin/env bash
# Validate build configuration before running CI/CD
# This checks all prerequisites and configuration issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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

cd "$PROJECT_DIR"

ERRORS=0
WARNINGS=0

echo "=== Build Configuration Validation ==="
echo ""

# Check required files
log_info "Checking required files..."
REQUIRED_FILES=(
    "build.sh"
    "profile/profiledef.sh"
    "profile/packages.x86_64"
    "profile/pacman.conf"
    "profile/airootfs/etc/mkinitcpio.conf"
    "profile/airootfs/etc/pacman.d/mirrorlist"
    "profile/airootfs/root/customize_airootfs.sh"
    "profile/airootfs/root/.automated_script.sh"
    "profile/efiboot/loader/loader.conf"
    "profile/efiboot/loader/entries/01-archiso-x86_64-linux.conf"
    "profile/syslinux/archiso_sys.cfg"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Missing required file: $file"
        ((ERRORS++)) || true
    else
        log_info "✓ $file"
    fi
done

# Check required directories
log_info ""
log_info "Checking required directories..."
REQUIRED_DIRS=(
    "profile"
    "profile/airootfs"
    "profile/airootfs/etc"
    "profile/airootfs/etc/pacman.d"
    "profile/airootfs/etc/pacman.d/hooks"
    "profile/airootfs/root"
    "profile/efiboot"
    "profile/efiboot/loader"
    "profile/efiboot/loader/entries"
    "profile/syslinux"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        log_error "Missing required directory: $dir"
        ((ERRORS++)) || true
    else
        log_info "✓ $dir"
    fi
done

# Check script permissions
log_info ""
log_info "Checking script permissions..."
SCRIPTS=(
    "build.sh"
    "profile/airootfs/root/customize_airootfs.sh"
    "profile/airootfs/root/.automated_script.sh"
    "profile/airootfs/root/post-install.sh"
    "profile/airootfs/root/install-helper.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ ! -x "$script" ]; then
        log_warn "Script not executable: $script (will be fixed in CI/CD)"
        ((WARNINGS++)) || true
    else
        log_info "✓ $script is executable"
    fi
done

# Validate profiledef.sh syntax
log_info ""
log_info "Validating profiledef.sh syntax..."
if bash -n profile/profiledef.sh 2>&1; then
    log_info "✓ profiledef.sh syntax is valid"
else
    log_error "profiledef.sh has syntax errors"
    ((ERRORS++)) || true
fi

# Check profiledef.sh variables
log_info ""
log_info "Checking profiledef.sh variables..."
source profile/profiledef.sh 2>/dev/null || true

if [ -z "${profile_name:-}" ]; then
    log_error "profile_name is not set in profiledef.sh"
    ((ERRORS++)) || true
else
    log_info "✓ profile_name: $profile_name"
fi

if [ -z "${install_dir:-}" ]; then
    log_error "install_dir is not set in profiledef.sh"
    ((ERRORS++)) || true
else
    log_info "✓ install_dir: $install_dir"
fi

if [ -z "${arch:-}" ]; then
    log_error "arch is not set in profiledef.sh"
    ((ERRORS++)) || true
else
    log_info "✓ arch: $arch"
fi

# Validate packages.x86_64
log_info ""
log_info "Validating packages.x86_64..."
if [ -f profile/packages.x86_64 ]; then
    if grep -q "uutils-coreutils" profile/packages.x86_64; then
        log_info "✓ uutils-coreutils in package list"
    else
        log_error "uutils-coreutils not found in packages.x86_64"
        ((ERRORS++)) || true
    fi

    if grep -q "^coreutils$" profile/packages.x86_64; then
        log_error "GNU coreutils should not be in packages.x86_64"
        ((ERRORS++)) || true
    else
        log_info "✓ GNU coreutils not in package list (correct)"
    fi
fi

# Validate pacman.conf
log_info ""
log_info "Validating pacman.conf..."
if [ -f profile/pacman.conf ]; then
    if grep -q "^IgnorePkg.*coreutils" profile/pacman.conf; then
        log_info "✓ coreutils in IgnorePkg"
    else
        log_error "coreutils not in IgnorePkg in pacman.conf"
        ((ERRORS++)) || true
    fi
fi

# Validate boot configuration files
log_info ""
log_info "Validating boot configuration..."
if [ -f profile/efiboot/loader/entries/01-archiso-x86_64-linux.conf ]; then
    if grep -q "%INSTALL_DIR%" profile/efiboot/loader/entries/01-archiso-x86_64-linux.conf; then
        log_info "✓ EFI boot config uses INSTALL_DIR placeholder"
    else
        log_warn "EFI boot config may not use INSTALL_DIR placeholder"
        ((WARNINGS++)) || true
    fi
fi

if [ -f profile/syslinux/archiso_sys.cfg ]; then
    if grep -q "%INSTALL_DIR%" profile/syslinux/archiso_sys.cfg; then
        log_info "✓ Syslinux config uses INSTALL_DIR placeholder"
    else
        log_warn "Syslinux config may not use INSTALL_DIR placeholder"
        ((WARNINGS++)) || true
    fi
fi

# Check for mirrorlist file (critical fix)
log_info ""
log_info "Checking mirrorlist file..."
if [ -f profile/airootfs/etc/pacman.d/mirrorlist ]; then
    log_info "✓ mirrorlist file exists (critical for build)"
else
    log_error "mirrorlist file is missing - this will cause realpath error!"
    ((ERRORS++)) || true
fi

# Validate bash script syntax
log_info ""
log_info "Validating bash script syntax..."
SCRIPT_COUNT=0
while IFS= read -r -d '' script || [ -n "$script" ]; do
    if [ -n "$script" ]; then
        SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
        if bash -n "$script" 2>&1; then
            log_info "✓ $(basename "$script")"
        else
            log_error "Syntax error in: $script"
            ((ERRORS++)) || true
        fi
    fi
done < <(find . -name "*.sh" -type f ! -path "./.git/*" ! -path "./work/*" ! -path "./out/*" ! -path "./build/*" -print0 2>/dev/null || true)

# Summary
echo ""
echo "=== Validation Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    log_info "✓ All checks passed! Build should work in CI/CD."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    log_warn "Build should work, but there are $WARNINGS warning(s)"
    exit 0
else
    log_error "Found $ERRORS error(s) and $WARNINGS warning(s)"
    log_error "Please fix the errors before running CI/CD"
    exit 1
fi


