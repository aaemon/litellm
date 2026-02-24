#!/bin/bash
# apply_customizations.sh
# Applies all fork-specific UI customizations to the LiteLLM dashboard.
# Designed to be idempotent — safe to run multiple times.
# Each customization is a discrete function that targets content patterns, not line numbers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UI_SRC="$REPO_ROOT/ui/litellm-dashboard/src"

SUCCESS_COUNT=0
FAIL_COUNT=0

log_success() {
    echo "  ✅ $1"
    ((SUCCESS_COUNT++))
}

log_fail() {
    echo "  ❌ $1"
    ((FAIL_COUNT++))
}

log_skip() {
    echo "  ⏭️  $1 (already applied)"
}

# ─────────────────────────────────────────────────────────────────
# 1. Remove default credentials Alert from LoginPage.tsx
# ─────────────────────────────────────────────────────────────────
apply_remove_default_credentials() {
    local file="$UI_SRC/app/login/LoginPage.tsx"
    echo "🔧 Removing default credentials from login page..."

    if ! grep -q "Default Credentials" "$file" 2>/dev/null; then
        log_skip "Default credentials already removed"
        return
    fi

    # Remove the Alert block with default credentials info
    # Use perl for multi-line pattern matching
    perl -i -0pe 's/\s*<Alert\s*\n\s*message="Default Credentials".*?\/>\n//s' "$file"

    # Remove unused InfoCircleOutlined import if present
    sed -i '/import { InfoCircleOutlined } from "@ant-design\/icons";/d' "$file"

    if ! grep -q "Default Credentials" "$file"; then
        log_success "Removed default credentials from login page"
    else
        log_fail "Failed to remove default credentials from login page"
    fi
}

# ─────────────────────────────────────────────────────────────────
# 2. Remove CommunityEngagementButtons from navbar
# ─────────────────────────────────────────────────────────────────
apply_remove_community_buttons() {
    local file="$UI_SRC/components/navbar.tsx"
    echo "🔧 Removing community buttons from navbar..."

    if ! grep -q "CommunityEngagementButtons" "$file" 2>/dev/null; then
        log_skip "Community buttons already removed"
        return
    fi

    # Remove import line
    sed -i '/import { CommunityEngagementButtons } from/d' "$file"

    # Remove usage
    sed -i '/<CommunityEngagementButtons/d' "$file"

    if ! grep -q "CommunityEngagementButtons" "$file"; then
        log_success "Removed community buttons from navbar"
    else
        log_fail "Failed to remove community buttons from navbar"
    fi
}

# ─────────────────────────────────────────────────────────────────
# 3. Add password field to CreateUserButton.tsx
# ─────────────────────────────────────────────────────────────────
apply_add_password_to_create_user() {
    local file="$UI_SRC/components/CreateUserButton.tsx"
    echo "🔧 Adding password field to Create User form..."

    if grep -q 'name="password"' "$file" 2>/dev/null; then
        log_skip "Password field already present in CreateUserButton"
        return
    fi

    # Add password field after "User Email" field in both embedded and standalone forms
    # Match the closing tag of User Email form item and add password field after it
    sed -i '/<Form.Item label="User Email" name="user_email">/,/<\/Form.Item>/{
        /<\/Form.Item>/a\        <Form.Item label="Password" name="password" tooltip="Set a password for the user to log in with">\n          <Input.Password placeholder="Set user password" />\n        </Form.Item>
    }' "$file"

    if grep -q 'name="password"' "$file"; then
        log_success "Added password field to Create User form"
    else
        log_fail "Failed to add password field to Create User form"
    fi
}

# ─────────────────────────────────────────────────────────────────
# 4. Add password field to edit_user.tsx
# ─────────────────────────────────────────────────────────────────
apply_add_password_to_edit_user() {
    local file="$UI_SRC/components/edit_user.tsx"
    echo "🔧 Adding password field to Edit User modal..."

    if grep -q 'label="Set Password"' "$file" 2>/dev/null; then
        log_skip "Password field already present in Edit User modal"
        return
    fi

    # Add password field after User Email field
    sed -i '/label="User Email".*name="user_email"/,/<\/Form.Item>/{
        /<\/Form.Item>/a\\n          <Form.Item label="Set Password" tooltip="Set a new password for the user (leave empty to keep current)" name="password">\n            <TextInput type="password" placeholder="Enter new password" \/>\n          <\/Form.Item>
    }' "$file"

    if grep -q 'label="Set Password"' "$file"; then
        log_success "Added password field to Edit User modal"
    else
        log_fail "Failed to add password field to Edit User modal"
    fi
}

# ─────────────────────────────────────────────────────────────────
# 5. Remove duplicate Save button from edit_user.tsx
# ─────────────────────────────────────────────────────────────────
apply_remove_duplicate_save_button() {
    local file="$UI_SRC/components/edit_user.tsx"
    echo "🔧 Checking for duplicate Save button in Edit User modal..."

    # Count number of Save buttons
    local count
    count=$(grep -c 'htmlType="submit">Save</Button2>' "$file" 2>/dev/null || echo "0")

    if [ "$count" -le 1 ]; then
        log_skip "No duplicate Save button found"
        return
    fi

    # Remove the second occurrence (keep only the first)
    # Use awk to remove the second Save button block
    awk '
    /htmlType="submit">Save<\/Button2>/ {
        save_count++
        if (save_count >= 2) {
            # Skip this line and the surrounding div tags
            skip = 1
            next
        }
    }
    /textAlign.*right.*marginTop/ {
        if (skip == 0) { div_count++ }
        if (div_count >= 2 && save_count < 2) { skip = 1; next }
    }
    { if (!skip) print; skip = 0 }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    local new_count
    new_count=$(grep -c 'htmlType="submit">Save</Button2>' "$file" 2>/dev/null || echo "0")
    if [ "$new_count" -le 1 ]; then
        log_success "Removed duplicate Save button"
    else
        log_skip "Could not auto-remove duplicate (manual check may be needed)"
    fi
}

# ─────────────────────────────────────────────────────────────────
# 6. Customize UI Message in proxy_server.py
# ─────────────────────────────────────────────────────────────────
apply_customize_ui_message() {
    local file="litellm/proxy/proxy_server.py"
    echo "🔧 Customizing login UI message in proxy_server.py..."

    # Check if already customized (dynamic version - no hardcoded IP)
    if grep -q 'f"👉 \[```Login```\]({ui_link}/login)' "$file" 2>/dev/null; then
        log_skip "Login UI message already customized"
        return
    fi

    # Replace the original upstream ui_message line with our custom version
    # Uses {ui_link} which is already computed dynamically by the proxy
    sed -i 's|ui_message = f"👉 \[```LiteLLM Admin Panel on /ui```\]({ui_link})\. Create, Edit Keys with SSO\. Having issues? Try \[```Fallback Login```\]({fallback_login_link})"|ui_message = f"👉 [```Login```]({ui_link}/login). Having issues? Try [```Fallback Login```]({fallback_login_link})"|' "$file"

    if grep -q '{ui_link}/login' "$file"; then
        log_success "Customized login UI message (uses dynamic url)"
    else
        log_fail "Failed to customize login UI message"
    fi
}

# ─────────────────────────────────────────────────────────────────
# 7. Remove version badge from navbar
# ─────────────────────────────────────────────────────────────────
apply_remove_version_badge() {
    local file="$UI_SRC/components/navbar.tsx"
    echo "🔧 Removing version badge from navbar..."

    if ! grep -q "{version && (" "$file" 2>/dev/null; then
        log_skip "Version badge already removed"
        return
    fi

    # Remove the {version && (...)} block
    perl -i -0pe 's/\s+\{version && \(.*?\)\}\n//s' "$file"

    if ! grep -q "{version && (" "$file"; then
        log_success "Removed version badge from navbar"
    else
        log_fail "Failed to remove version badge from navbar"
    fi
}

# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────
echo "================================================"
echo "  LiteLLM Fork — Applying Customizations"
echo "================================================"
echo ""

apply_remove_default_credentials
apply_remove_community_buttons
apply_add_password_to_create_user
apply_add_password_to_edit_user
apply_remove_duplicate_save_button
apply_customize_ui_message
apply_remove_version_badge

echo ""
echo "================================================"
echo "  Results: $SUCCESS_COUNT applied, $FAIL_COUNT failed"
echo "================================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "⚠️  Some customizations failed to apply. Please check the output above."
    exit 1
fi

echo "✅ All customizations applied successfully!"
