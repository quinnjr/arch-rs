#!/usr/bin/env bash
# Installation helper script for ArchLinux with rust coreutils
# This script should be run during the installation process to ensure
# rust coreutils is installed instead of GNU coreutils

set -euo pipefail

MOUNTPOINT="${1:-/mnt}"

if [ ! -d "$MOUNTPOINT" ]; then
    echo "Error: Mountpoint $MOUNTPOINT does not exist"
    exit 1
fi

echo "Configuring installation for rust-based utilities..."

# Create pacman hooks to prevent GNU utilities installation
mkdir -p "$MOUNTPOINT/etc/pacman.d/hooks"

# GNU packages to exclude and their replacements
declare -A GNU_REPLACEMENTS=(
    ["coreutils"]="uutils-coreutils"
    ["grep"]="ripgrep"
    ["findutils"]="fd"
    ["sed"]="sd"
    ["procps-ng"]="procs bottom"
)

# Create hooks for each GNU package
for gnu_pkg in "${!GNU_REPLACEMENTS[@]}"; do
    cat > "$MOUNTPOINT/etc/pacman.d/hooks/${gnu_pkg}-replace.hook" << EOF
[Trigger]
Type = Package
Operation = Install
Target = ${gnu_pkg}

[Action]
Description = Preventing GNU ${gnu_pkg} installation (replaced by Rust alternatives)
When = PreTransaction
Exec = /usr/bin/pacman -Rns --noconfirm ${gnu_pkg} || true
EOF
done

# Configure pacman to exclude all GNU packages
if [ -f "$MOUNTPOINT/etc/pacman.conf" ]; then
    # Add all GNU packages to IgnorePkg if not already present
    if ! grep -q "^IgnorePkg.*coreutils" "$MOUNTPOINT/etc/pacman.conf"; then
        sed -i '/^#IgnorePkg/s/^#IgnorePkg/IgnorePkg = coreutils grep findutils sed procps-ng\n#IgnorePkg/' "$MOUNTPOINT/etc/pacman.conf" || \
        sed -i '/^\[options\]/a IgnorePkg = coreutils grep findutils sed procps-ng' "$MOUNTPOINT/etc/pacman.conf"
    else
        # Update existing IgnorePkg line
        if ! grep -q "^IgnorePkg.*grep" "$MOUNTPOINT/etc/pacman.conf"; then
            sed -i '/^IgnorePkg/s/coreutils/coreutils grep findutils sed procps-ng/' "$MOUNTPOINT/etc/pacman.conf"
        fi
    fi
fi

# If pacstrap was already run, replace GNU utilities now
if [ -d "$MOUNTPOINT/usr/bin" ]; then
    echo "Replacing GNU utilities with Rust alternatives in installed system..."
    arch-chroot "$MOUNTPOINT" bash -c "
        GNU_PACKAGES=(coreutils grep findutils sed procps-ng)
        for pkg in \"\${GNU_PACKAGES[@]}\"; do
            if pacman -Q \"\$pkg\" &> /dev/null; then
                pacman -Rns --noconfirm \"\$pkg\" || true
            fi
        done
        if ! pacman -Q uutils-coreutils &> /dev/null; then
            pacman -S --noconfirm uutils-coreutils
        fi
    " || echo "Note: Run this after pacstrap completes"
fi

echo "✓ Installation helper configuration complete!"
echo ""
echo "When installing packages, use:"
echo "  arch-chroot $MOUNTPOINT pacman -S base --ignore coreutils,grep,findutils,sed,procps-ng"
echo "  arch-chroot $MOUNTPOINT pacman -S uutils-coreutils"
echo ""
echo "Install Rust utility replacements:"
echo "  arch-chroot $MOUNTPOINT pacman -S ripgrep fd bat eza procs bottom dust zoxide starship tealdeer sd tokei hyperfine"

