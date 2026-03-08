#!/bin/bash
# SPDX-Licence-Identifier: MIT OR Apache-2.0
# =============================================================================
# VS Code Tunnel Setup — Release Helper
# =============================================================================
# Bumps the version, updates all version references, commits, tags, and pushes.
#
# Usage:
#   ./deploy.sh [LEVEL]
#
# Levels:
#   patch (default) — 0.3.0 → 0.3.1
#   minor           — 0.3.0 → 0.4.0
#   major           — 0.3.0 → 1.0.0
# =============================================================================

set -e

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: ./deploy.sh [LEVEL]"
    echo ""
    echo "${BOLD}VS Code Tunnel Setup — Release Helper${NC}"
    echo "--------------------------------------"
    echo ""
    echo "Levels:"
    echo "  patch (default) — 0.3.0 → 0.3.1"
    echo "  minor           — 0.3.0 → 0.4.0"
    echo "  major           — 0.3.0 → 1.0.0"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh           # Bump patch version and release"
    echo "  ./deploy.sh minor     # Bump minor version and release"
    echo "  ./deploy.sh major     # Bump major version and release"
    echo ""
    echo "This script will:"
    echo "  1. Bump the version in VERSION and setup-vscode-tunnel.sh"
    echo "  2. Run all tests"
    echo "  3. Commit and tag (v\$VERSION)"
    echo "  4. Push to origin (triggers GitHub Release workflow)"
    exit 0
fi

LEVEL=${1:-patch}

# ── Pre-flight checks ────────────────────────────────────────────────────────

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo -e "${RED}Error: You are on branch '$CURRENT_BRANCH'. Releases are only allowed from 'main'.${NC}"
    exit 1
fi

if [[ -n $(git status -s) ]]; then
    echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}"
    git status -s
    exit 1
fi

if [[ "$LEVEL" != "patch" && "$LEVEL" != "minor" && "$LEVEL" != "major" ]]; then
    echo -e "${RED}Error: Invalid level '$LEVEL'. Use 'patch', 'minor', or 'major'.${NC}"
    exit 1
fi

if [[ ! -f VERSION ]]; then
    echo -e "${RED}Error: VERSION file not found.${NC}"
    exit 1
fi

CURRENT_VERSION=$(cat VERSION | tr -d '[:space:]')
echo -e "Current version: ${YELLOW}$CURRENT_VERSION${NC}"

# ── Bump version ──────────────────────────────────────────────────────────────

# Pure bash version bump (no python dependency)
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$LEVEL" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
TAG_NAME="v${NEW_VERSION}"

echo -e "New version:     ${GREEN}$NEW_VERSION${NC} (${LEVEL})"
echo -e "Tag:             ${CYAN}$TAG_NAME${NC}"
echo ""

# Check if tag already exists
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Tag $TAG_NAME already exists.${NC}"
    echo -n "Overwrite? [y/N]: "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        git tag -d "$TAG_NAME"
        git push origin ":refs/tags/$TAG_NAME" 2>/dev/null || true
    else
        echo "Aborted."
        exit 1
    fi
fi

# ── Update version references ────────────────────────────────────────────────

echo -e "${CYAN}Updating version references...${NC}"

# Update VERSION file
echo "$NEW_VERSION" > VERSION
echo -e "  ${GREEN}✓${NC} VERSION"

# Update SCRIPT_VERSION in setup-vscode-tunnel.sh
sed -i '' "s/^SCRIPT_VERSION=\".*\"/SCRIPT_VERSION=\"$NEW_VERSION\"/" setup-vscode-tunnel.sh
echo -e "  ${GREEN}✓${NC} setup-vscode-tunnel.sh (SCRIPT_VERSION)"

# Update CHANGELOG.md — add compare link for new version
if [[ -f CHANGELOG.md ]]; then
    # Add new version compare link if not present
    if ! grep -q "\[${NEW_VERSION}\]" CHANGELOG.md; then
        sed -i '' "s|\[Unreleased\]:.*|[Unreleased]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v${NEW_VERSION}...HEAD\n[${NEW_VERSION}]: https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/compare/v${CURRENT_VERSION}...v${NEW_VERSION}|" CHANGELOG.md
    fi
    echo -e "  ${GREEN}✓${NC} CHANGELOG.md (compare links)"
fi

echo ""

# ── Run tests ─────────────────────────────────────────────────────────────────

echo -e "${CYAN}Running tests...${NC}"
echo ""

if ! bash -n setup-vscode-tunnel.sh; then
    echo -e "${RED}Error: Syntax check failed.${NC}"
    exit 1
fi

if ! make test-unit 2>&1 | tail -5; then
    echo -e "${RED}Error: Unit tests failed. Aborting release.${NC}"
    git checkout -- VERSION setup-vscode-tunnel.sh CHANGELOG.md 2>/dev/null
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All tests passed${NC}"
echo ""

# ── Confirm ───────────────────────────────────────────────────────────────────

echo -e "${BOLD}Ready to release v${NEW_VERSION}${NC}"
echo -e "  This will commit, tag, and push to origin."
echo -e "  The GitHub Release workflow will create the release automatically."
echo ""
echo -n "  Proceed? [y/N]: "
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Aborted. Rolling back version changes...${NC}"
    git checkout -- VERSION setup-vscode-tunnel.sh CHANGELOG.md 2>/dev/null
    exit 0
fi

# ── Commit, tag, push ────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}Committing...${NC}"
git add VERSION setup-vscode-tunnel.sh CHANGELOG.md
git commit -m "chore(release): bump version to $NEW_VERSION"

echo -e "${CYAN}Tagging ${TAG_NAME}...${NC}"
git tag -a "$TAG_NAME" -m "Release $NEW_VERSION"

echo -e "${CYAN}Pushing to origin...${NC}"
git push origin main
git push origin "$TAG_NAME"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN} ${NC}  ${BOLD}✅ Released v${NEW_VERSION}${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  GitHub Release: ${CYAN}https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/releases/tag/$TAG_NAME${NC}"
echo -e "  Actions:        ${CYAN}https://github.com/XMV-Solutions-GmbH/vscode-tunnel-setup/actions${NC}"
echo ""
