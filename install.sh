#!/usr/bin/env bash
# Install the agent-dev-flow skills for Claude Code, plus the skills they depend on.
#
#   ./install.sh                  link this repo's skills + install required deps
#   ./install.sh --with-optional  also install optional deps (browser checks)
#   ./install.sh --copy           copy instead of symlink (no auto-update on git pull)
#   ./install.sh --check          only report what is installed and what is missing
#
# Own skills are symlinked into ~/.claude/skills by default, so `git pull` here
# updates them. An existing skill of the same name is moved to
# ~/.claude/skills/.backup-<date>/ first, never deleted.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE=link; OPTIONAL=0; CHECK=0; FAILED=0
for a in "$@"; do
  case "$a" in
    --with-optional) OPTIONAL=1 ;;
    --copy) MODE=copy ;;
    --check) CHECK=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
miss() { printf '  \033[33m•\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
have_skill() { [ -f "$DEST/$1/SKILL.md" ]; }

command -v jq >/dev/null 2>&1 || { echo "jq is required to read deps.json (brew install jq)" >&2; exit 1; }
DEPS="$ROOT/deps.json"

echo "Tools"
missing_tool=0
for kind in required optional; do
  while IFS=$'\t' read -r name why hint; do
    if command -v "$name" >/dev/null 2>&1; then ok "$name"
    elif [ "$kind" = required ]; then bad "$name - $why${hint:+ ($hint)}"; missing_tool=1
    else miss "$name (optional) - $why"; fi
  done < <(jq -r --arg k "$kind" '.tools[$k][] | [.name, .why, (.install // "")] | @tsv' "$DEPS")
done

echo "Skills in this repo -> $DEST"
mkdir -p "$DEST"
backup="$DEST/.backup-$(date +%Y%m%d-%H%M%S)"
for dir in "$ROOT"/skills/*/; do
  name=$(basename "$dir")
  target="$DEST/$name"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "${dir%/}" ]; then ok "$name (linked)"; continue; fi
  if [ "$CHECK" = 1 ]; then
    if have_skill "$name"; then miss "$name present but not from this repo"; else miss "$name not installed"; fi
    continue
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then mkdir -p "$backup"; mv "$target" "$backup/"; fi
  if [ "$MODE" = link ]; then ln -s "${dir%/}" "$target"; else cp -R "${dir%/}" "$target"; fi
  find "$target/" -name '*.sh' -exec chmod +x {} +
  ok "$name ($MODE)"
done
[ -d "$backup" ] && echo "  previous copies moved to $backup"

install_skill() { # name source
  if have_skill "$1"; then ok "$1 (already installed)"; return; fi
  if [ "$CHECK" = 1 ]; then miss "$1 - not installed (from $2)"; return; fi
  local log="${TMPDIR:-/tmp}/agent-dev-flow-$1.log" try
  # </dev/null: npx must not read the loop's stdin, or the loop stops after one skill.
  for try in 1 2 3; do
    npx --yes skills@latest add "$2" -s "$1" -g -a claude-code -y </dev/null >"$log" 2>&1 || true
    if have_skill "$1"; then ok "$1 (installed from $2)"; return; fi
    [ "$try" -lt 3 ] && sleep $((try * 5))
  done
  if grep -q 'Failed to clone\|Could not resolve\|Couldn.t connect' "$log" 2>/dev/null; then
    bad "$1 - could not reach GitHub (network/proxy?). Set HTTPS_PROXY and rerun ./install.sh"
  else
    bad "$1 - install failed, see $log; manual: npx skills add $2 -s $1 -g -a claude-code"
  fi
  FAILED=1
}

echo "Required skills"
while IFS=$'\t' read -r name src; do install_skill "$name" "$src"; done \
  < <(jq -r '.skills.required[] | [.name, .source] | @tsv' "$DEPS")

echo "Optional skills"
while IFS=$'\t' read -r name src why; do
  if [ "$OPTIONAL" = 1 ]; then install_skill "$name" "$src"
  elif have_skill "$name"; then ok "$name (already installed)"
  else miss "$name - $why (run with --with-optional)"; fi
done < <(jq -r '.skills.optional[] | [.name, .source, .why] | @tsv' "$DEPS")

echo
if [ "$missing_tool" = 1 ] || [ "$FAILED" = 1 ]; then echo "Not complete: fix the ✗ items above and rerun ./install.sh (it skips what is already there)."; exit 1; fi
echo "Done. In a repo, start with /agent-kit once, then /work <需求> for every task."
