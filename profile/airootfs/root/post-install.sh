#!/usr/bin/env bash
# Post-installation script to run on the installed system
# This ensures rust-based utilities are properly configured after installation

set -euo pipefail

echo "Configuring rust-based utilities on installed system..."

# Remove GNU utilities if present
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

# Install uutils-coreutils if not present
if ! pacman -Q uutils-coreutils &> /dev/null; then
    echo "Installing uutils-coreutils..."
    pacman -S --noconfirm uutils-coreutils
fi

# Configure pacman to ignore GNU packages
if [ -f /etc/pacman.conf ]; then
    if ! grep -q "^IgnorePkg.*coreutils" /etc/pacman.conf; then
        # Add IgnorePkg line with all GNU packages to exclude
        if grep -q "^IgnorePkg" /etc/pacman.conf; then
            # Append to existing IgnorePkg line
            sed -i '/^IgnorePkg/s/$/ coreutils grep findutils sed procps-ng/' /etc/pacman.conf
        else
            # Create new IgnorePkg line
            sed -i '/^\[options\]/a IgnorePkg = coreutils grep findutils sed procps-ng' /etc/pacman.conf
        fi
    else
        # Update existing IgnorePkg line to include all GNU packages
        if ! grep -q "^IgnorePkg.*grep" /etc/pacman.conf; then
            sed -i '/^IgnorePkg/s/coreutils/coreutils grep findutils sed procps-ng/' /etc/pacman.conf
        fi
    fi
fi

# Create pacman hooks to prevent future GNU utilities installation
mkdir -p /etc/pacman.d/hooks

# Create hooks for each GNU package
for gnu_pkg in "${GNU_PACKAGES[@]}"; do
    hook_file="/etc/pacman.d/hooks/${gnu_pkg}-replace.hook"
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
done

# Ensure uutils binaries are in PATH and preferred
# uutils-coreutils installs binaries with 'coreutils-' prefix
# Create symlinks for common commands
if command -v coreutils-ls &> /dev/null; then
    for cmd in ls cat cp mv rm mkdir rmdir chmod chown ln find grep head tail wc sort uniq; do
        if command -v "coreutils-$cmd" &> /dev/null; then
            # Only create symlink if command doesn't exist or is already a symlink
            if [ ! -e "/usr/bin/$cmd" ] || [ -L "/usr/bin/$cmd" ]; then
                ln -sf "coreutils-$cmd" "/usr/bin/$cmd" 2>/dev/null || true
            fi
        fi
    done
fi

# Install Rust-based utility replacements
echo "Installing Rust-based utility replacements..."
RUST_PACKAGES=(
    "ripgrep"
    "fd"
    "bat"
    "eza"
    "procs"
    "bottom"
    "dust"
    "zoxide"
    "starship"
    "tealdeer"
    "sd"
    "tokei"
    "hyperfine"
)

for pkg in "${RUST_PACKAGES[@]}"; do
    if ! pacman -Q "$pkg" &> /dev/null; then
        echo "Installing $pkg..."
        pacman -S --noconfirm "$pkg" || echo "⚠ Failed to install $pkg (may not be available)"
    fi
done

# Create wrapper scripts in /usr/local/bin for system-wide access
# This allows scripts (not just interactive shells) to use Rust utilities
mkdir -p /usr/local/bin

# Create wrapper functions
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
create_rust_wrapper "grep" "rg"
create_rust_wrapper "find" "fd"
create_rust_wrapper "cat" "bat" "--paging=never"  # Disable paging for scripts
create_rust_wrapper "sed" "sd"
create_rust_wrapper "ls" "eza"
create_rust_wrapper "ps" "procs"
create_rust_wrapper "top" "btm"
create_rust_wrapper "htop" "btm"
create_rust_wrapper "du" "dust"

# Create aliases for interactive shells
mkdir -p /etc/profile.d
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

# Update shell profiles
for profile in /etc/profile /etc/bash.bashrc; do
    if [ -f "$profile" ]; then
        # Ensure /usr/local/bin is in PATH (for wrapper scripts)
        if ! grep -q 'export PATH="/usr/local/bin:\$PATH"' "$profile" && ! grep -q 'export PATH=.*/usr/local/bin' "$profile"; then
            echo 'export PATH="/usr/local/bin:$PATH"' >> "$profile"
        fi
        # Source rust-utils.sh for aliases
        if ! grep -q "rust-utils.sh" "$profile"; then
            echo 'if [ -f /etc/profile.d/rust-utils.sh ]; then source /etc/profile.d/rust-utils.sh; fi' >> "$profile"
        fi
        # Prefer uutils-coreutils binaries
        if ! grep -q "uutils-coreutils" "$profile"; then
            cat >> "$profile" << 'PROFILE_EOF'

# Prefer uutils-coreutils binaries
if command -v coreutils-ls &> /dev/null; then
    export PATH="/usr/bin:$PATH"
fi
PROFILE_EOF
        fi
    fi
done

echo "✓ Rust-based utilities configuration complete!"
echo ""
echo "Verifying installation:"
echo ""

# Check uutils-coreutils
if command -v ls &> /dev/null; then
    if ls --version 2>&1 | grep -q "uutils"; then
        echo "✓ Rust coreutils (uutils-coreutils) is active"
    else
        echo "⚠ Warning: GNU coreutils may still be present"
        echo "  Run: pacman -Rns coreutils && pacman -S uutils-coreutils"
    fi
fi

# Check other Rust utilities
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

echo "Rust utility status:"
for util_info in "${RUST_UTILS[@]}"; do
    IFS=':' read -r pkg_name cmd_name <<< "$util_info"
    if command -v "$cmd_name" &> /dev/null; then
        echo "  ✓ $pkg_name ($cmd_name)"
    else
        echo "  ✗ $pkg_name ($cmd_name) - not installed"
    fi
done

echo ""
echo "✓ Rust utilities are now aliased to their GNU counterparts"
echo "  - Interactive shells: Aliases in /etc/profile.d/rust-utils.sh"
echo "  - Scripts: Wrapper scripts in /usr/local/bin"
echo "  - Commands like 'grep', 'find', 'cat', 'ls', etc. now use Rust versions"

