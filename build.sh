#!/usr/bin/env bash
# Build script for ArchLinux ISO with rust coreutils
#
# Copyright (c) 2024 ArchLinux ISO with Rust Utilities Contributors
# Licensed under the MIT License

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${SCRIPT_DIR}/profile"
WORK_DIR="${SCRIPT_DIR}/work"
OUTPUT_DIR="${SCRIPT_DIR}/out"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if archiso is installed
if ! command -v mkarchiso &> /dev/null; then
    log_error "archiso is not installed. Please install it with:"
    log_error "  sudo pacman -S archiso"
    exit 1
fi

# Check if profile directory exists
if [ ! -d "$PROFILE_DIR" ]; then
    log_error "Profile directory not found: $PROFILE_DIR"
    exit 1
fi

# Clean previous builds if requested
if [ "${1:-}" = "--clean" ]; then
    log_info "Cleaning previous build artifacts..."
    rm -rf "$WORK_DIR" "$OUTPUT_DIR"
fi

# Create output directories
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

log_info "Starting ISO build process..."
log_info "Profile: $PROFILE_DIR"
log_info "Work directory: $WORK_DIR"
log_info "Output directory: $OUTPUT_DIR"

# Verify profiledef.sh exists
if [ ! -f "$PROFILE_DIR/profiledef.sh" ]; then
    log_error "profiledef.sh not found in profile directory"
    exit 1
fi

# Build the ISO
log_info "Building ISO with mkarchiso..."
log_info "Using profile directory: $PROFILE_DIR"
if mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" "$PROFILE_DIR"; then
    log_info "✓ ISO build completed successfully!"
    log_info "ISO files are located in: $OUTPUT_DIR"

    # List generated files
    if [ -d "$OUTPUT_DIR" ]; then
        log_info "Generated files:"
        ls -lh "$OUTPUT_DIR" | tail -n +2
    fi
else
    log_error "ISO build failed!"
    exit 1
fi

