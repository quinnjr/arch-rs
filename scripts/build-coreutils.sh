#!/usr/bin/env bash
# Optional script to build rust core-utils from source
# This is not required if using the uutils-coreutils package from AUR/repos

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/../build/coreutils"
REPO_URL="https://github.com/uutils/coreutils.git"

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    log_error "Rust/Cargo is not installed. Please install it with:"
    log_error "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

log_info "Building rust core-utils from source..."

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone repository if it doesn't exist
if [ ! -d "coreutils" ]; then
    log_info "Cloning uutils/coreutils repository..."
    git clone "$REPO_URL" coreutils
fi

cd coreutils

# Update repository
log_info "Updating repository..."
git pull

# Build
log_info "Building coreutils (this may take a while)..."
cargo build --release --features "default"

log_info "✓ Build complete!"
log_info "Binaries are located in: $BUILD_DIR/coreutils/target/release/"

