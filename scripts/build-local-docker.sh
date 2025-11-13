#!/usr/bin/env bash
# Local build script that replicates CI/CD Docker build process
# This ensures the build works the same way locally as in CI/CD

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

# Check if Docker is available (try both Linux and Windows paths)
DOCKER_CMD=""
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
elif [ -f "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]; then
    DOCKER_CMD="/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"
    log_info "Using Windows Docker Desktop"
else
    log_error "Docker is not installed or not in PATH"
    log_error "Please install Docker Desktop and enable WSL integration"
    exit 1
fi

# Check if Docker daemon is running
if ! $DOCKER_CMD info &> /dev/null 2>&1; then
    log_error "Docker daemon is not running"
    log_error "Please start Docker Desktop and try again"
    exit 1
else
    log_info "Docker daemon is running"
fi

VERSION="${1:-v1.0.0-test}"
ISO_NAME="arch-rs"

log_info "Building ISO locally using Docker (replicating CI/CD process)"
log_info "Version: $VERSION"
log_info "ISO Name: $ISO_NAME"
echo ""

# Run the build in Docker container (same as CI/CD)
log_info "Starting Docker build container..."
$DOCKER_CMD run --rm \
    --privileged \
    -v "$PROJECT_DIR":/workspace:rw \
    -w /workspace \
    archlinux:latest \
    bash -c "
        set -e
        echo '=== Updating system ==='
        pacman -Syu --noconfirm

        echo ''
        echo '=== Installing dependencies ==='
        pacman -S --noconfirm archiso git

        echo ''
        echo '=== Making scripts executable ==='
        chmod +x build.sh profile/airootfs/root/*.sh scripts/*.sh 2>/dev/null || true

        echo ''
        echo '=== Verifying profile structure ==='
        if [ ! -f profile/profiledef.sh ]; then
            echo 'ERROR: profile/profiledef.sh not found'
            exit 1
        fi
        if [ ! -f profile/packages.x86_64 ]; then
            echo 'ERROR: profile/packages.x86_64 not found'
            exit 1
        fi
        echo 'Profile structure verified'

        echo ''
        echo '=== Building ISO ==='
        ./build.sh --clean

        echo ''
        echo '=== Finding ISO file ==='
        ISO_FILE=\$(find out -name '*.iso' -type f | head -1)
        if [ -z \"\$ISO_FILE\" ]; then
            echo 'ERROR: No ISO file found in out/ directory'
            ls -la out/ || true
            exit 1
        fi

        ISO_DIR=\$(dirname \"\$ISO_FILE\")
        NEW_NAME=\"${ISO_NAME}-${VERSION}.iso\"
        NEW_PATH=\"\$ISO_DIR/\$NEW_NAME\"

        if [ -f \"\$ISO_FILE\" ]; then
            cp \"\$ISO_FILE\" \"\$NEW_PATH\"
            echo \"ISO built: \$NEW_PATH\"
            ls -lh \"\$NEW_PATH\"

            # Calculate checksums
            echo ''
            echo '=== ISO Checksums ==='
            echo \"SHA256: \$(sha256sum \"\$NEW_PATH\" | cut -d' ' -f1)\"
            echo \"MD5: \$(md5sum \"\$NEW_PATH\" | cut -d' ' -f1)\"
            echo \"Size: \$(du -h \"\$NEW_PATH\" | cut -f1)\"
        else
            echo 'ERROR: ISO file not found after build'
            exit 1
        fi
    "

if [ $? -eq 0 ]; then
    echo ""
    log_info "✓ Build completed successfully!"
    log_info "ISO files are in: $PROJECT_DIR/out/"
    ls -lh "$PROJECT_DIR/out/" 2>/dev/null || true
else
    log_error "✗ Build failed!"
    exit 1
fi

