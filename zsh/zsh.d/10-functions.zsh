#!/bin/zsh
# Utility functions

# backup existing dotfiles (buo: back-up-original)
function buo() {
    backup_dir="$HOME/dotfiles_backup"
    for name in "$@"; do
        path="$HOME/$name"
        if [ -f "$path" ] || [ -h "$path" ] || [ -d "$path" ]; then
            mkdir -p "$backup_dir"
            new_path="$backup_dir/$name"
            printf "Found '$path'. Backing up to '$new_path'\n"
            mv "$path" "$new_path"
        fi
    done
}

# colorprint: display file with ANSI colors
function colorprint() {
    cat "$1" | sed -E 's/\[([0-9;]+)m/\x1b[\1m/g'
}

# rsync with custom port
function myrsync() {
    local port="$1"
    local remainder="$2"
    local cmd="rsync -avzhe 'ssh -p ${port}' ${remainder}"
    echo "$cmd"
    eval "$cmd"
}

# count files matching pattern
function howmany() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo 'Count files with PATTERN in LOCATION'
        echo 'Usage: howmany LOCATION "PATTERN"'
        echo 'Example: howmany /path/to/images/ "*.jpg"'
        return 1
    fi
    set -o noglob
    local dirname="$1"
    local pattern="$2"
    find "${dirname}" -name "${pattern}" -printf '.' | wc -m
    set -o glob
}

# clean python cache files
function pyclean() {
    find . | grep -E '(/__pycache__$|\.pyc$|\.pyo$|\.ipynb_checkpoints$)' | xargs rm -rf
}

# fzf + vim integration
function fuzzyvim() {
    vim "$(fzf)"
}

# GPU device selection
function usegpu() {
    if [ -n "$1" ]; then
        export CUDA_VISIBLE_DEVICES="$1"
    else
        export CUDA_VISIBLE_DEVICES=''
    fi
}

# HPU device selection (Habana)
function usehpu() {
    if [ -n "$1" ]; then
        export HABANA_VISIBLE_MODULES="$1"
    else
        export HABANA_VISIBLE_MODULES=''
    fi
}

# Oh-My-ClaudeCode update (with per-component version tracking)
function omcupdate() {
    local force=false
    local GREEN='\033[0;32m' YELLOW='\033[1;33m' RED='\033[0;31m' BLUE='\033[0;34m' NC='\033[0m'

    [[ "$1" == "-f" || "$1" == "--force" ]] && force=true
    [[ "$1" == "-h" || "$1" == "--help" ]] && { echo "Usage: omcupdate [-f|--force]"; return 0; }

    command -v claude &>/dev/null || { echo -e "${RED}[ERROR]${NC} Claude CLI not found"; return 1; }

    local PLUGIN_DIR="$HOME/.claude/plugins/cache/omc/oh-my-claudecode"
    local MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/omc"
    local VERSION_FILE="$HOME/.claude/.omc-versions"
    local updated=false

    mkdir -p "$HOME/.claude/hud"
    touch "$VERSION_FILE"

    # Helper: get saved version
    _get_ver() { grep "^$1=" "$VERSION_FILE" 2>/dev/null | cut -d= -f2; }
    # Helper: save version
    _set_ver() { grep -v "^$1=" "$VERSION_FILE" > "${VERSION_FILE}.tmp" 2>/dev/null; echo "$1=$2" >> "${VERSION_FILE}.tmp"; mv "${VERSION_FILE}.tmp" "$VERSION_FILE"; }

    # 1. CLAUDE.md - check remote hash via ETag/Last-Modified
    local CLAUDE_MD="$HOME/.claude/CLAUDE.md"
    local REMOTE_HASH=$(curl -fsSI "https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/docs/CLAUDE.md" 2>/dev/null | grep -i "etag\|last-modified" | md5sum | cut -c1-8)
    local SAVED_HASH=$(_get_ver "claude_md")
    if [[ "$force" == "true" || "$REMOTE_HASH" != "$SAVED_HASH" || ! -f "$CLAUDE_MD" ]]; then
        echo -ne "${BLUE}[OMC]${NC} CLAUDE.md... "
        if curl -fsSL "https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/docs/CLAUDE.md" -o "$CLAUDE_MD" 2>/dev/null; then
            _set_ver "claude_md" "$REMOTE_HASH"
            echo -e "${GREEN}updated${NC}"
            updated=true
        else
            echo -e "${YELLOW}failed${NC}"
        fi
    fi

    # 2. Marketplace - check git remote HEAD
    if [[ -d "$MARKETPLACE_DIR/.git" ]]; then
        local LOCAL_HEAD=$(cd "$MARKETPLACE_DIR" && git rev-parse HEAD 2>/dev/null | cut -c1-8)
        local REMOTE_HEAD=$(cd "$MARKETPLACE_DIR" && git ls-remote origin main 2>/dev/null | cut -c1-8)
        if [[ "$force" == "true" || "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
            echo -ne "${BLUE}[OMC]${NC} Marketplace... "
            if (cd "$MARKETPLACE_DIR" && git pull origin main --quiet 2>/dev/null); then
                echo -e "${GREEN}updated${NC}"
                updated=true
            else
                echo -e "${YELLOW}failed${NC}"
            fi
        fi
    fi

    # 3. Plugin - check if new version available
    local CURRENT_VER=$(ls "$PLUGIN_DIR" 2>/dev/null | sort -V | tail -1)
    local MARKETPLACE_VER=$(grep '"version"' "$MARKETPLACE_DIR/package.json" 2>/dev/null | head -1 | sed 's/.*"\([0-9.]*\)".*/\1/')
    if [[ "$force" == "true" || "$CURRENT_VER" != "$MARKETPLACE_VER" ]]; then
        echo -ne "${BLUE}[OMC]${NC} Plugin ($CURRENT_VER → $MARKETPLACE_VER)... "
        if command claude plugin update oh-my-claudecode@omc 2>/dev/null | grep -q "updated\|already"; then
            echo -e "${GREEN}updated${NC}"
            updated=true
        else
            echo -e "${YELLOW}failed${NC}"
        fi
    fi

    # Get current plugin version (may have changed)
    local VERSION=$(ls "$PLUGIN_DIR" 2>/dev/null | sort -V | tail -1)
    [[ -z "$VERSION" ]] && { echo -e "${RED}[ERROR]${NC} No plugin found"; return 1; }
    local PLUGIN_PATH="$PLUGIN_DIR/$VERSION"

    # 4. Build plugin if needed
    if [[ ! -f "$PLUGIN_PATH/dist/hud/index.js" ]]; then
        echo -ne "${BLUE}[OMC]${NC} Building plugin... "
        if (cd "$PLUGIN_PATH" && npm install --silent 2>/dev/null); then
            echo -e "${GREEN}done${NC}"
            updated=true
        else
            echo -e "${YELLOW}failed${NC}"
        fi
    fi

    # 5. HUD wrapper - check if matches current version
    local HUD_WRAPPER="$HOME/.claude/hud/omc-hud.mjs"
    local SAVED_HUD_VER=$(_get_ver "hud")
    if [[ "$force" == "true" || "$SAVED_HUD_VER" != "$VERSION" || ! -f "$HUD_WRAPPER" ]]; then
        cat > "$HUD_WRAPPER" << 'EOF'
#!/usr/bin/env node
import { existsSync, readdirSync } from 'fs';
import { join } from 'path';
const pluginDir = join(process.env.HOME, '.claude/plugins/cache/omc/oh-my-claudecode');
if (!existsSync(pluginDir)) process.exit(0);
const versions = readdirSync(pluginDir).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
const latest = versions[versions.length - 1];
if (!latest) process.exit(0);
const hudPath = join(pluginDir, latest, 'dist/hud/index.js');
if (!existsSync(hudPath)) process.exit(0);
import(hudPath).catch(() => process.exit(0));
EOF
        chmod +x "$HUD_WRAPPER"
        _set_ver "hud" "$VERSION"
        echo -e "${BLUE}[OMC]${NC} HUD... ${GREEN}updated${NC}"
        updated=true
    fi

    # 6. settings.json statusLine
    local CLAUDE_SETTINGS="$HOME/.claude/settings.json"
    local HUD_CMD="node ~/.claude/hud/omc-hud.mjs"
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        if ! grep -q "$HUD_CMD" "$CLAUDE_SETTINGS" 2>/dev/null; then
            command -v jq &>/dev/null && jq --arg cmd "$HUD_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
            echo -e "${BLUE}[OMC]${NC} statusLine... ${GREEN}configured${NC}"
            updated=true
        fi
    else
        echo "{\"statusLine\": {\"type\": \"command\", \"command\": \"$HUD_CMD\"}}" > "$CLAUDE_SETTINGS"
        updated=true
    fi

    # Summary
    if [[ "$updated" == "true" ]]; then
        echo -e "${GREEN}[OMC]${NC} Updated to v$VERSION"
    else
        echo -e "${GREEN}[OMC]${NC} Already up to date (v$VERSION)"
    fi
}
