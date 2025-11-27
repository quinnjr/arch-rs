#!/usr/bin/env bash
# Build script that waits for Docker and monitors the build process

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

cd "$PROJECT_DIR"

# Detect Docker command
DOCKER_CMD=""
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
elif [ -f "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]; then
    DOCKER_CMD="/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"
else
    log_error "Docker is not installed"
    log_error "Please install Docker Desktop and enable WSL integration"
    exit 1
fi

# Wait for Docker to be available
log_step "Waiting for Docker Desktop to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if $DOCKER_CMD info &> /dev/null 2>&1; then
        log_info "Docker is ready!"
        break
    fi
    if [ $WAIT_COUNT -eq 0 ]; then
        log_warn "Docker Desktop is not running. Please start Docker Desktop."
        log_warn "Waiting up to ${MAX_WAIT} seconds for Docker to become available..."
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    echo -n "."
done
echo ""

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    log_error "Docker did not become available within ${MAX_WAIT} seconds"
    log_error "Please start Docker Desktop and try again"
    exit 1
fi

VERSION="${1:-v1.0.0-test}"
ISO_NAME="arch-rs"

log_info "=== Starting ISO Build ==="
log_info "Version: $VERSION"
log_info "ISO Name: $ISO_NAME"
log_info "This will take 10-30 minutes depending on your system..."
echo ""

# Run the build with full output
log_step "Pulling ArchLinux Docker image (if needed)..."
$DOCKER_CMD pull archlinux:latest 2>&1 | grep -E "(Pulling|Already|Downloaded|Extracting|Status)" || true

echo ""
log_step "Starting build container..."
echo ""

# Run the build in Docker container with full monitoring
$DOCKER_CMD run --rm \
    --privileged \
    -v "$PROJECT_DIR":/workspace:rw \
    -w /workspace \
    archlinux:latest \
    bash -c "
        set -e
        echo '=== [1/6] Updating system ==='
        pacman -Syu --noconfirm 2>&1 | tail -5

        echo ''
        echo '=== [2/6] Installing dependencies ==='
        pacman -S --noconfirm archiso git 2>&1 | tail -5

        echo ''
        echo '=== [3/6] Making scripts executable ==='
        chmod +x build.sh profile/airootfs/root/*.sh scripts/*.sh 2>/dev/null || true
        echo 'Scripts are executable'

        echo ''
        echo '=== [4/6] Verifying profile structure ==='
        if [ ! -f profile/profiledef.sh ]; then
            echo 'ERROR: profile/profiledef.sh not found'
            exit 1
        fi
        if [ ! -f profile/packages.x86_64 ]; then
            echo 'ERROR: profile/packages.x86_64 not found'
            exit 1
        fi
        if [ ! -f profile/airootfs/etc/pacman.d/mirrorlist ]; then
            echo 'ERROR: mirrorlist file is missing!'
            exit 1
        fi
        echo 'Profile structure verified ✓'

        echo ''
        echo '=== [5/6] Building ISO (this takes 10-20 minutes) ==='
        echo 'Starting mkarchiso...'
        ./build.sh --clean

        echo ''
        echo '=== [6/6] Finding and preparing ISO file ==='
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
            echo \"ISO built successfully: \$NEW_PATH\"
            ls -lh \"\$NEW_PATH\"

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

BUILD_EXIT_CODE=$?

echo ""
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    log_info "=== Build Completed Successfully! ==="
    log_info "ISO files are in: $PROJECT_DIR/out/"
    echo ""
    ls -lh "$PROJECT_DIR/out/" 2>/dev/null | grep -E "\.iso|total" || true
else
    log_error "=== Build Failed! ==="
    log_error "Exit code: $BUILD_EXIT_CODE"
    log_error "Check the output above for error details"
    exit 1
fi

