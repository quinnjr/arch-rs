#!/usr/bin/env bash
# This script is executed automatically by archiso's live environment

set -euo pipefail

echo "Setting up rust-based utilities environment..."

# Ensure uutils-coreutils binaries are in PATH and take precedence
# The binaries are typically installed as /usr/bin/coreutils-<command>
# We need to create symlinks or ensure they're accessible

# Create symlinks for common coreutils commands if they don't exist
# uutils-coreutils installs binaries with the 'coreutils-' prefix
# We'll create symlinks to make them accessible directly

if command -v coreutils-ls &> /dev/null; then
    # Create symlinks for common commands
    for cmd in ls cat cp mv rm mkdir rmdir chmod chown ln find grep head tail wc sort uniq; do
        if [ ! -e "/usr/bin/$cmd" ] || [ -L "/usr/bin/$cmd" ]; then
            if command -v "coreutils-$cmd" &> /dev/null; then
                ln -sf "coreutils-$cmd" "/usr/bin/$cmd" 2>/dev/null || true
            fi
        fi
    done
fi

# Verify coreutils replacement
if command -v ls &> /dev/null; then
    if ls --version 2>&1 | grep -q "uutils"; then
        echo "✓ Rust coreutils (uutils-coreutils) is active"
    else
        echo "⚠ Warning: GNU coreutils may still be present"
    fi
fi

# Display available Rust utilities
echo ""
echo "Available Rust-based utilities (now aliased by default):"
echo "  Search: grep -> rg (ripgrep), find -> fd, cat -> bat, sed -> sd"
echo "  Files:  ls -> eza, du -> dust"
echo "  System: ps -> procs, top/htop -> btm"
echo "  Other:  cd -> zoxide (smart), prompt -> starship, tldr, tokei, hyperfine"
echo ""
echo "✓ Rust utilities are active - standard commands now use Rust versions"
echo "  Wrapper scripts in /usr/local/bin for scripts"
echo "  Aliases in /etc/profile.d/rust-utils.sh for interactive shells"

echo "Setup complete!"

