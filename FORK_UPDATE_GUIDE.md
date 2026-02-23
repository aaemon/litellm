# Fork Update Guide

This document explains how to keep this forked LiteLLM repository up-to-date with the upstream [BerriAI/litellm](https://github.com/BerriAI/litellm) repository.

## Overview

This fork includes custom UI and backend modifications. When syncing with upstream, our customizations are automatically re-applied using the `scripts/apply_customizations.sh` script.

## Fork-Specific Customizations

| Area | Change | File(s) |
|------|--------|---------|
| Login Page | Removed default credentials banner | `LoginPage.tsx` |
| Login Page | Changed "Username" to "Username or Email" | `LoginPage.tsx` |
| Navbar | Removed Slack & GitHub community buttons | `navbar.tsx` |
| Navbar | Removed version badge (❄️v1.x.x) | `navbar.tsx` |
| User Creation | Added "Create User" with email + password | `CreateUserButton.tsx` |
| User Creation | Removed password from invitation flow | `CreateUserButton.tsx` |
| User Editing | Added "Set Password" field | `edit_user.tsx` |
| Key Creation | Made team selection optional | `create_key_button.tsx` |
| Backend | Password support in `/user/new` endpoint | `_types.py`, `internal_user_endpoints.py` |
| Backend | Default budget set to $0 for new users | `_types.py` |

## Method 1: Manual Sync (Local)

```bash
# From the repo root
./scripts/sync_upstream.sh
```

### What it does

1. Adds the upstream remote (`https://github.com/BerriAI/litellm.git`) if needed
2. Fetches latest changes from upstream `main`
3. Merges upstream changes into your current branch
4. Re-applies all fork customizations via `scripts/apply_customizations.sh`

### Options

```bash
# Sync and rebuild the UI
./scripts/sync_upstream.sh --rebuild-ui

# Sync without rebuilding the UI
./scripts/sync_upstream.sh
```

### Handling Merge Conflicts

If the sync encounters merge conflicts:

1. The script will stop and list the conflicting files
2. Resolve each conflict manually (search for `<<<<<<<` markers)
3. Stage the resolved files: `git add <file>`
4. Complete the merge: `git commit`
5. Re-run the customization script: `./scripts/apply_customizations.sh`
6. Rebuild the UI if needed (see [Rebuilding the UI](#rebuilding-the-ui))

## Method 2: Automated via GitHub Actions

A GitHub Actions workflow (`.github/workflows/sync-upstream.yml`) handles syncing automatically.

### Triggers

- **Scheduled**: Runs weekly (every Monday at 00:00 UTC)
- **Manual**: Go to **Actions** → **Sync Upstream** → **Run workflow**

### What it does

1. Syncs upstream changes
2. Re-applies customizations
3. Rebuilds the UI
4. Pushes to the fork
5. **Creates a GitHub issue** if merge conflicts are detected

## Rebuilding the UI

After any changes to frontend files, rebuild the UI:

```bash
cd ui/litellm-dashboard
npm run build
rm -rf ../../litellm/proxy/_experimental/out/*
cp -r ./out/* ../../litellm/proxy/_experimental/out/
rm -rf ./out
```

## Rebuilding Docker

After syncing and rebuilding the UI:

```bash
docker compose build --no-cache litellm
docker compose up -d litellm db
```

## Adding New Customizations

When making new fork-specific changes:

1. Make your code changes
2. Add a corresponding function to `scripts/apply_customizations.sh`
3. Make the function **idempotent** (safe to run multiple times)
4. Use **content-based patterns** (not line numbers) for resilience
5. Test by running `./scripts/apply_customizations.sh` on a clean upstream checkout

### Example customization function

```bash
apply_my_new_change() {
    local file="ui/litellm-dashboard/src/components/SomeComponent.tsx"
    if [ ! -f "$file" ]; then
        echo "  ⚠ $file not found, skipping"
        return
    fi

    # Use sed with content patterns, not line numbers
    if grep -q "original text" "$file"; then
        sed -i 's/original text/replacement text/g' "$file"
        echo "  ✓ Applied my new change"
    else
        echo "  ✓ My new change already applied"
    fi
}
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/sync_upstream.sh` | Manual sync script |
| `scripts/apply_customizations.sh` | Applies all fork-specific changes |
| `.github/workflows/sync-upstream.yml` | Automated sync workflow |
| `docker-compose.yml` | Local Docker setup (port 4001) |
| `config.yaml` | Proxy configuration |
