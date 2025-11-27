#!/usr/bin/env bash
# This script is run inside the chroot during ISO build
# It customizes the root filesystem before the ISO is created

set -euo pipefail

echo "Customizing root filesystem for rust-based utilities..."

# Configure DNS resolution
echo "Configuring DNS resolution..."
# Ensure systemd-resolved is enabled
systemctl enable systemd-resolved.service 2>/dev/null || true

# Configure resolv.conf to use systemd-resolved stub resolver
if [ -f /etc/resolv.conf ]; then
    # Backup original if it exists and isn't already a symlink
    if [ ! -L /etc/resolv.conf ]; then
        mv /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
    fi
    # Create symlink to systemd-resolved stub resolver
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
fi

# Ensure systemd-resolved configuration directory exists
mkdir -p /etc/systemd/resolved.conf.d

# Configure DNS servers if not already configured
if [ ! -f /etc/systemd/resolved.conf.d/archiso.conf ]; then
    cat > /etc/systemd/resolved.conf.d/archiso.conf << 'RESOLVED_EOF'
[Resolve]
# Use reliable DNS servers
DNS=1.1.1.1 8.8.8.8 1.0.0.1 8.8.4.4
FallbackDNS=9.9.9.9 208.67.222.222
# Use systemd-resolved stub resolver
DNSStubListener=yes
# Enable DNSSEC
DNSSEC=allow-downgrade
# Cache DNS responses
Cache=yes
RESOLVED_EOF
fi

echo "DNS configuration completed"

# Configure NetworkManager to use systemd-resolved
echo "Configuring NetworkManager for DNS..."
mkdir -p /etc/NetworkManager/conf.d
if [ ! -f /etc/NetworkManager/conf.d/dns.conf ]; then
    cat > /etc/NetworkManager/conf.d/dns.conf << 'NM_DNS_EOF'
[main]
# Use systemd-resolved for DNS resolution
dns=systemd-resolved
NM_DNS_EOF
fi

# Enable NetworkManager and systemd-resolved services
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable systemd-resolved.service 2>/dev/null || true

echo "NetworkManager DNS configuration completed"

# Remove GNU utilities if they were accidentally installed
# These are replaced by Rust alternatives
GNU_PACKAGES=(
    "coreutils"      # Replaced by uutils-coreutils
    "grep"           # Replaced by ripgrep
    "findutils"      # Replaced by fd
    "sed"            # Replaced by sd
    "procps-ng"      # Replaced by procs and bottom
)

echo "Removing GNU utilities replaced by Rust alternatives..."
for pkg in "${GNU_PACKAGES[@]}"; do
    if pacman -Q "$pkg" &> /dev/null; then
        echo "Removing GNU $pkg..."
        pacman -Rns --noconfirm "$pkg" || true
    fi
done

# Ensure uutils-coreutils is installed
if ! pacman -Q uutils-coreutils &> /dev/null; then
    echo "Installing uutils-coreutils..."
    pacman -S --noconfirm uutils-coreutils
fi

# Create wrapper script to ensure uutils binaries are used
cat > /usr/local/bin/ensure-uutils.sh << 'EOF'
#!/bin/bash
# Ensure uutils-coreutils binaries are preferred
export PATH="/usr/bin:$PATH"
EOF
chmod +x /usr/local/bin/ensure-uutils.sh

# Update shell profiles to prefer uutils and Rust utilities
for profile in /etc/profile /etc/bash.bashrc /root/.bashrc; do
    if [ -f "$profile" ]; then
        # Ensure /usr/local/bin is in PATH (for wrapper scripts)
        if ! grep -q "/usr/local/bin" "$profile"; then
            echo 'export PATH="/usr/local/bin:$PATH"' >> "$profile"
        fi
        # Source rust-utils.sh for aliases
        if ! grep -q "rust-utils.sh" "$profile"; then
            echo 'if [ -f /etc/profile.d/rust-utils.sh ]; then source /etc/profile.d/rust-utils.sh; fi' >> "$profile"
        fi
        # Source ensure-uutils for uutils-coreutils
        if ! grep -q "ensure-uutils" "$profile"; then
            echo "source /usr/local/bin/ensure-uutils.sh" >> "$profile"
        fi
    fi
done

# Ensure pacman.conf excludes GNU packages (this will be copied to installed systems)
if [ -f /etc/pacman.conf ]; then
    if ! grep -q "^IgnorePkg.*coreutils" /etc/pacman.conf; then
        # Add IgnorePkg line with all GNU packages to exclude
        sed -i '/^#IgnorePkg/s/^#IgnorePkg/IgnorePkg = coreutils grep findutils sed procps-ng\n#IgnorePkg/' /etc/pacman.conf || \
        sed -i '/^\[options\]/a IgnorePkg = coreutils grep findutils sed procps-ng' /etc/pacman.conf
    else
        # Update existing IgnorePkg line to include all GNU packages
        if ! grep -q "^IgnorePkg.*grep" /etc/pacman.conf; then
            sed -i '/^IgnorePkg/s/coreutils/coreutils grep findutils sed procps-ng/' /etc/pacman.conf
        fi
    fi
fi

# Install pacman hooks to prevent GNU utilities installation
mkdir -p /etc/pacman.d/hooks

# Create hooks for each GNU package
for gnu_pkg in "${GNU_PACKAGES[@]}"; do
    hook_file="/etc/pacman.d/hooks/${gnu_pkg}-replace.hook"
    if [ ! -f "$hook_file" ]; then
        cat > "$hook_file" << HOOK_EOF
[Trigger]
Type = Package
Operation = Install
Target = ${gnu_pkg}

[Action]
Description = Preventing GNU ${gnu_pkg} installation (replaced by Rust alternatives)
When = PreTransaction
Exec = /usr/bin/pacman -Rns --noconfirm ${gnu_pkg} || true
HOOK_EOF
    fi
done

# Install and configure Rust-based utility replacements
echo "Installing Rust-based utility replacements..."

# Ensure eza and other Rust utilities are installed (they should be from packages.x86_64)
# But verify and install if missing
RUST_UTILS_TO_CHECK=("ripgrep" "fd" "bat" "eza" "procs" "bottom" "dust" "zoxide" "starship" "tealdeer" "sd" "tokei" "hyperfine")
for util in "${RUST_UTILS_TO_CHECK[@]}"; do
    if ! command -v "$util" &> /dev/null && ! pacman -Q "$util" &> /dev/null; then
        echo "Installing missing Rust utility: $util"
        pacman -S --noconfirm "$util" || echo "⚠ Warning: Failed to install $util"
    fi
done

# Create wrapper scripts in /usr/local/bin for system-wide access
# This allows scripts (not just interactive shells) to use Rust utilities
mkdir -p /usr/local/bin

# Create wrapper functions that will be used by aliases and wrappers
create_rust_wrapper() {
    local original_cmd="$1"
    local rust_cmd="$2"
    local extra_args="${3:-}"

    if command -v "$rust_cmd" &> /dev/null; then
        cat > "/usr/local/bin/$original_cmd" << EOF
#!/bin/bash
# Wrapper script to use Rust-based $rust_cmd instead of GNU $original_cmd
exec "$rust_cmd" $extra_args "\$@"
EOF
        chmod +x "/usr/local/bin/$original_cmd"
    fi
}

# Create wrappers for Rust utilities
# Note: We put /usr/local/bin early in PATH so these take precedence
create_rust_wrapper "grep" "rg"
create_rust_wrapper "find" "fd"
create_rust_wrapper "cat" "bat" "--paging=never"  # Disable paging for scripts
create_rust_wrapper "sed" "sd"
create_rust_wrapper "ls" "eza"
create_rust_wrapper "ps" "procs"
create_rust_wrapper "top" "btm"
create_rust_wrapper "htop" "btm"
create_rust_wrapper "du" "dust"

# Create aliases for interactive shells (these take precedence over wrappers)
cat > /etc/profile.d/rust-utils.sh << 'RUST_UTILS_EOF'
# Rust-based utility aliases - Active by default
# These aliases make Rust utilities the default for interactive shells

# Ensure /usr/local/bin is in PATH (for wrapper scripts)
export PATH="/usr/local/bin:$PATH"

# Search and text processing
if command -v rg &> /dev/null; then
    alias grep='rg'
fi
if command -v fd &> /dev/null; then
    alias find='fd'
fi
if command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
    # Also create a 'bat' alias that allows paging for interactive use
    alias batp='bat'
fi
if command -v sd &> /dev/null; then
    alias sed='sd'
fi

# File listing (eza overrides uutils ls)
if command -v eza &> /dev/null; then
    alias ls='eza'
    alias ll='eza -l'
    alias la='eza -la'
    alias lt='eza --tree'
    alias tree='eza --tree'
fi

# System monitoring
if command -v procs &> /dev/null; then
    alias ps='procs'
fi
if command -v btm &> /dev/null; then
    alias top='btm'
    alias htop='btm'
fi
if command -v dust &> /dev/null; then
    alias du='dust'
fi

# Navigation (zoxide - smart cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init bash)"
fi

# Shell prompt (starship)
if command -v starship &> /dev/null; then
    eval "$(starship init bash)"
fi

# Documentation (tealdeer provides 'tldr' command, no alias needed)
RUST_UTILS_EOF

# Verify Rust utilities installation
echo "Verifying Rust utilities installation..."
RUST_UTILS=(
    "ripgrep:rg"
    "fd:fd"
    "bat:bat"
    "eza:eza"
    "procs:procs"
    "bottom:btm"
    "dust:dust"
    "zoxide:zoxide"
    "starship:starship"
    "tealdeer:tldr"
    "sd:sd"
    "tokei:tokei"
    "hyperfine:hyperfine"
)

INSTALLED=0
MISSING=0

for util_info in "${RUST_UTILS[@]}"; do
    IFS=':' read -r pkg_name cmd_name <<< "$util_info"
    if command -v "$cmd_name" &> /dev/null; then
        echo "✓ $pkg_name ($cmd_name) installed"
        ((INSTALLED++)) || true
    else
        echo "⚠ $pkg_name ($cmd_name) not found"
        ((MISSING++)) || true
    fi
done

# Verify uutils-coreutils
if command -v coreutils-ls &> /dev/null; then
    echo "✓ uutils-coreutils installed successfully"
    ((INSTALLED++)) || true
else
    echo "⚠ Warning: uutils-coreutils binaries not found"
    ((MISSING++)) || true
fi

echo ""
echo "Installed: $INSTALLED Rust utilities"
if [ $MISSING -gt 0 ]; then
    echo "Missing: $MISSING utilities (may need to install from AUR or build from source)"
fi

echo "Root filesystem customization complete!"

