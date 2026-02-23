#!/bin/bash
# sync_upstream.sh
# Syncs the fork with the latest changes from the main LiteLLM repo,
# then re-applies our customizations.
#
# Usage:
#   ./scripts/sync_upstream.sh              # Sync and apply customizations
#   ./scripts/sync_upstream.sh --no-build   # Sync without rebuilding UI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_URL="https://github.com/BerriAI/litellm.git"
UPSTREAM_BRANCH="main"
NO_BUILD=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-build) NO_BUILD=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

cd "$REPO_ROOT"

echo "================================================"
echo "  LiteLLM Fork — Upstream Sync"
echo "================================================"
echo ""

# Step 1: Add upstream remote if not present
echo "📡 Setting up upstream remote..."
if git remote get-url upstream &>/dev/null; then
    echo "   Upstream remote already configured"
else
    git remote add upstream "$UPSTREAM_URL"
    echo "   Added upstream remote: $UPSTREAM_URL"
fi

# Step 2: Fetch latest upstream
echo ""
echo "📥 Fetching latest upstream/$UPSTREAM_BRANCH..."
git fetch upstream "$UPSTREAM_BRANCH"

# Step 3: Show what's new
echo ""
echo "📊 Changes since last sync:"
AHEAD=$(git rev-list --count HEAD..upstream/$UPSTREAM_BRANCH 2>/dev/null || echo "?")
BEHIND=$(git rev-list --count upstream/$UPSTREAM_BRANCH..HEAD 2>/dev/null || echo "?")
echo "   Upstream is $AHEAD commits ahead, fork is $BEHIND commits ahead"

if [ "$AHEAD" = "0" ]; then
    echo ""
    echo "✅ Already up to date with upstream!"
    exit 0
fi

# Step 4: Merge upstream
echo ""
echo "🔀 Merging upstream/$UPSTREAM_BRANCH..."
if git merge "upstream/$UPSTREAM_BRANCH" --no-edit; then
    echo "   Merge completed successfully"
else
    echo ""
    echo "⚠️  Merge conflicts detected!"
    echo "   Please resolve conflicts manually, then run:"
    echo "   ./scripts/apply_customizations.sh"
    exit 1
fi

# Step 5: Re-apply customizations
echo ""
echo "🔧 Re-applying fork customizations..."
bash "$SCRIPT_DIR/apply_customizations.sh"

# Step 6: Build UI (optional)
if [ "$NO_BUILD" = false ]; then
    echo ""
    echo "🏗️  Building UI..."
    cd "$REPO_ROOT/ui/litellm-dashboard"

    if command -v npm &>/dev/null; then
        npm install --legacy-peer-deps 2>/dev/null || true
        npm run build

        # Copy built files
        DEST="$REPO_ROOT/litellm/proxy/_experimental/out"
        rm -rf "$DEST"/*
        cp -r ./out/* "$DEST"/
        rm -rf ./out

        echo "   UI build completed and copied to _experimental/out"
    else
        echo "   ⚠️  npm not found, skipping UI build"
        echo "   Run manually: cd ui/litellm-dashboard && npm run build"
    fi
else
    echo ""
    echo "⏭️  Skipping UI build (--no-build flag)"
fi

echo ""
echo "================================================"
echo "  ✅ Sync complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff HEAD~1"
echo "  2. Test locally: litellm --config proxy_config.yaml"
echo "  3. Push to fork: git push origin main"
