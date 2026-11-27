#!/usr/bin/env bash
set -e
git init -q
mkdir -p .claude/hooks src
printf '%s\n' '{ "name": "app", "type": "module", "scripts": { "check": "node --test", "test": "node --test" } }' > package.json
printf '%s\n' '#!/usr/bin/env bash' 'npm run check || exit 2' > .claude/hooks/verify.sh
cat > .claude/settings.json <<'JSON'
{ "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/verify.sh\"" } ] } ] } }
JSON
printf '%s\n' 'export const x = 1;' > src/index.js
