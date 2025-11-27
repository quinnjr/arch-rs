#!/usr/bin/env bash
# Publish script for creating and pushing release tags
# Tags are in YYYY.MM.DD format (e.g., 2025.11.27)

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

# Parse arguments
PUSH_TAG=false
TAG_DATE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --push|-p)
            PUSH_TAG=true
            shift
            ;;
        --date|-d)
            TAG_DATE="$2"
            shift 2
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Create a release tag in YYYY.MM.DD format"
            echo ""
            echo "Options:"
            echo "  --push, -p          Push the tag to remote after creating"
            echo "  --date, -d DATE     Use specific date (YYYY.MM.DD format)"
            echo "  --dry-run, -n       Show what would be done without doing it"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  # Create tag with today's date"
            echo "  $0 --push           # Create and push tag with today's date"
            echo "  $0 --date 2025.12.01 # Create tag with specific date"
            echo "  $0 --date 2025.12.01 --push # Create and push specific date tag"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate date format if provided
if [ -n "$TAG_DATE" ]; then
    if [[ ! "$TAG_DATE" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]]; then
        log_error "Invalid date format: $TAG_DATE"
        log_error "Date must be in YYYY.MM.DD format (e.g., 2025.11.27)"
        exit 1
    fi

    # Validate date is valid
    if ! date -d "${TAG_DATE//./-}" &>/dev/null 2>&1 && ! date -j -f "%Y.%m.%d" "$TAG_DATE" &>/dev/null 2>&1; then
        log_error "Invalid date: $TAG_DATE"
        exit 1
    fi

    VERSION_TAG="$TAG_DATE"
else
    # Use today's date
    if date --version &>/dev/null 2>&1; then
        # GNU date
        VERSION_TAG=$(date +"%Y.%m.%d")
    else
        # BSD date (macOS)
        VERSION_TAG=$(date +"%Y.%m.%d")
    fi
fi

log_step "Preparing to create release tag: $VERSION_TAG"

# Check if we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    log_warn "Current branch is '$CURRENT_BRANCH', not 'main' or 'master'"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
fi

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    log_warn "Working directory has uncommitted changes:"
    git status --short
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
fi

# Check if tag already exists
if git rev-parse "$VERSION_TAG" &>/dev/null 2>&1; then
    log_error "Tag '$VERSION_TAG' already exists!"
    log_info "Existing tag points to: $(git rev-parse "$VERSION_TAG")"
    exit 1
fi

# Get current commit info
CURRENT_COMMIT=$(git rev-parse HEAD)
COMMIT_SHORT=$(git rev-parse --short HEAD)
COMMIT_MSG=$(git log -1 --pretty=%B)

log_info "Current commit: $COMMIT_SHORT"
log_info "Commit message: ${COMMIT_MSG:0:60}..."

# Create tag message
TAG_MESSAGE="Release $VERSION_TAG

Build date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Commit: $CURRENT_COMMIT
"

if [ "$DRY_RUN" = true ]; then
    log_step "DRY RUN - Would execute:"
    echo ""
    echo "  git tag -a '$VERSION_TAG' -m '$TAG_MESSAGE'"
    if [ "$PUSH_TAG" = true ]; then
        echo "  git push origin '$VERSION_TAG'"
    fi
    echo ""
    log_info "Dry run complete. Use without --dry-run to actually create the tag."
    exit 0
fi

# Create the tag
log_step "Creating tag '$VERSION_TAG'..."
if git tag -a "$VERSION_TAG" -m "$TAG_MESSAGE"; then
    log_info "✓ Tag '$VERSION_TAG' created successfully"
else
    log_error "Failed to create tag"
    exit 1
fi

# Show tag info
log_info "Tag information:"
git show "$VERSION_TAG" --no-patch --format="  Tag: %D%n  Commit: %H%n  Author: %an <%ae>%n  Date: %ad" --date=format:"%Y-%m-%d %H:%M:%S %Z"

# Push tag if requested
if [ "$PUSH_TAG" = true ]; then
    log_step "Pushing tag to remote..."
    REMOTE=$(git remote | head -1 || echo "origin")
    if git push "$REMOTE" "$VERSION_TAG"; then
        log_info "✓ Tag '$VERSION_TAG' pushed to $REMOTE"
        log_info ""
        log_info "GitHub Actions will now build and release the ISO automatically."
    else
        log_error "Failed to push tag"
        log_warn "Tag was created locally but not pushed. Push manually with:"
        log_warn "  git push $REMOTE $VERSION_TAG"
        exit 1
    fi
else
    log_info ""
    log_warn "Tag created locally but not pushed."
    log_info "To push the tag, run:"
    log_info "  git push origin $VERSION_TAG"
    log_info ""
    log_info "Or use this script with --push:"
    log_info "  $0 --push"
fi

log_info ""
log_info "✓ Release tag '$VERSION_TAG' is ready!"
if [ "$PUSH_TAG" = true ]; then
    log_info "  The CI/CD pipeline will build and release the ISO automatically."
fi

