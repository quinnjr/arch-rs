#!/usr/bin/env bash
# Diagnostic build script to test network access in airootfs
# This helps diagnose CI/CD network issues

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

# Check if Docker is available
DOCKER_CMD=""
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
elif [ -f "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]; then
    DOCKER_CMD="/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"
    log_info "Using Windows Docker Desktop"
else
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! $DOCKER_CMD info &> /dev/null 2>&1; then
    log_error "Docker daemon is not running"
    exit 1
fi

VERSION="diagnostic-$(date +%Y%m%d-%H%M%S)"
ISO_NAME="arch-rs"

log_step "Starting diagnostic build to test network access in airootfs"
log_info "Version: $VERSION"
echo ""

# Run the build in Docker container with network diagnostics
log_step "Starting Docker build container with network diagnostics..."
$DOCKER_CMD run --rm \
    --privileged \
    --network host \
    -v "$PROJECT_DIR":/workspace:rw \
    -w /workspace \
    archlinux:latest \
    bash -c "
        set -e
        echo '=== [1/6] Updating system ==='
        pacman -Syu --noconfirm 2>&1 | tail -5

        echo ''
        echo '=== [2/6] Installing dependencies ==='
        pacman -S --noconfirm archiso git reflector curl 2>&1 | tail -5

        echo ''
        echo '=== [2.5/6] Testing host network connectivity ==='
        echo 'Testing DNS resolution on host...'
        if getent hosts archlinux.org > /dev/null 2>&1; then
            echo '✓ Host DNS resolution working'
        else
            echo '✗ Host DNS resolution failed'
        fi
        
        echo 'Testing HTTP connectivity on host...'
        if curl -s --max-time 5 https://archlinux.org > /dev/null 2>&1; then
            echo '✓ Host HTTP connectivity working'
        else
            echo '✗ Host HTTP connectivity failed'
        fi

        echo ''
        echo '=== [2.6/6] Updating mirrorlist ==='
        curl -s 'https://archlinux.org/mirrorlist/?country=US&country=DE&country=NL&protocol=https&ip_version=4&use_mirror_status=on' | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist 2>/dev/null && echo 'Official mirrorlist downloaded' || {
            echo 'Official mirrorlist download failed, trying reflector...'
            reflector --country 'United States,Germany,Netherlands' --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null && echo 'Reflector updated mirrorlist' || {
                echo 'Reflector failed, using fallback mirrors...'
                curl -s 'https://archlinux.org/mirrorlist/all/https/' | sed 's/^#Server/Server/' | head -20 > /etc/pacman.d/mirrorlist 2>/dev/null || true
            }
        }
        echo 'Mirrorlist updated'
        echo 'First few mirrors:'
        head -5 /etc/pacman.d/mirrorlist

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
        echo 'Profile structure verified ✓'

        echo ''
        echo '=== [5/6] Building ISO (this will test airootfs network access) ==='
        echo 'Starting mkarchiso...'
        echo 'Watch for network connectivity tests in customize_airootfs.sh output...'
        ./build.sh --clean 2>&1 | tee /tmp/build-output.log || {
            echo ''
            echo '=== BUILD FAILED - Checking logs ==='
            echo 'Last 50 lines of build output:'
            tail -50 /tmp/build-output.log
            echo ''
            echo 'Searching for network-related errors:'
            grep -i -E '(network|dns|resolve|connect|timeout|404|503)' /tmp/build-output.log | tail -20 || echo 'No network errors found in logs'
            exit 1
        }

        echo ''
        echo '=== [6/6] Build completed successfully ==='
        ISO_FILE=\$(find out -name '*.iso' -type f | head -1)
        if [ -n \"\$ISO_FILE\" ]; then
            echo \"ISO built: \$ISO_FILE\"
            ls -lh \"\$ISO_FILE\"
        fi
    "

if [ $? -eq 0 ]; then
    echo ""
    log_info "✓ Diagnostic build completed successfully!"
    log_info "Check the output above for network connectivity test results"
    log_info "ISO files are in: $PROJECT_DIR/out/"
else
    log_error "✗ Diagnostic build failed!"
    log_error "Review the network connectivity tests above to identify the issue"
    exit 1
fi

