#!/usr/bin/env bash
# push-sync-pr.sh — run this once from the eochat-app repo root to push the
# conduit v3.4.0 sync branch and open a PR.
#
# Prerequisites: git, gh (GitHub CLI, authenticated)
# Usage: cd /path/to/eochat-app && bash push-sync-pr.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BUNDLE="$REPO_ROOT/sync-branch-only.bundle"
BRANCH="sync/conduit-v3.4.0"

echo "==> Removing stale git lock (if any)..."
rm -f "$REPO_ROOT/.git/index.lock" "$REPO_ROOT/.git/MERGE_HEAD" "$REPO_ROOT/.git/ORIG_HEAD" 2>/dev/null || true

echo "==> Fetching merge commit from bundle..."
git fetch "$BUNDLE" "$BRANCH:$BRANCH"

echo "==> Pushing $BRANCH to origin..."
git push origin "$BRANCH"

echo "==> Creating pull request..."
gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "Sync with cogwheel0/conduit v3.4.0" \
  --body "## Upstream sync: cogwheel0/conduit → evangelischeomroep/eochat-app

Brings the fork up to date with [v3.4.0](https://github.com/cogwheel0/conduit/releases/tag/v3.4.0).

### What's new in v3.4.0

- **Offline-first persistence** — caches and attachment queue migrated from Hive to Drift (SQLite)
- **Preferences** migrated from Hive to \`shared_preferences\`
- **Rich-text notes** — Fleather editor with \`parchment\` document model
- **In-app notifications** — parity layer driven by socket events
- **Native voice pipeline** — STT/TTS bridges for iOS and Android; Personal Voice support on iOS
- **Open WebUI streaming parity** — modelName, optimistic state, fade caching, socket resume
- **WebSocket TLS connector** refactored; dependency pins de-risked
- **Five rotating dots** typing indicator replacing the old one
- Bug fixes: initial login sync refresh, debug log startup errors, graceful malformed-response handling
- Security: restrict external link schemes, auth headers scoped to origin, Mermaid strict mode

### Conflict resolutions

| File | Resolution |
|---|---|
| \`ios/Runner/Info.plist\` | Kept EOchat branding; added \`NSPersonalVoiceUsageDescription\` with EOchat copy |
| \`pubspec.yaml\` | Bumped to 3.4.0+132; added \`synchronized\`, \`drift\`, \`drift_flutter\`, \`fleather\`, \`parchment\` deps |
| \`lib/core/providers/app_startup_providers.dart\` | Kept fork imports alongside upstream's new \`local_conversation_loader\` import |
| \`lib/core/router/app_router.dart\` | Preserved fork-specific provider listeners (\`startupAuthStuck\`, connectivity, streaming) |
| \`lib/features/chat/widgets/modern_chat_input.dart\` | Kept fork overflow-icon conditions for web-search, image-gen, tools, terminal, filters |
| \`lib/core/auth/auth_state_manager.dart\` | Took upstream refactor (\`_performSilentLoginAttempt\`); it already includes the server-existence check |"

echo ""
echo "Done! PR created."
echo "You can clean up the bundle: rm \"$BUNDLE\""
