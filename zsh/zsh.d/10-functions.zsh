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

# Oh-My-ClaudeCode update
function omcupdate() {
    local setup_after=false
    local force=false
    local silent=false
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[0;34m'
    local NC='\033[0m'

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --setup|-s) setup_after=true; shift ;;
            --force|-f) force=true; shift ;;
            --silent|-q) silent=true; shift ;;
            --help|-h)
                echo "Usage: omcupdate [OPTIONS]"
                echo "Options:"
                echo "  --setup, -s    Run omc-setup after update"
                echo "  --force, -f    Force update even if already latest"
                echo "  --silent, -q   Silent mode (no output unless update needed)"
                echo "  --help, -h     Show this help"
                return 0
                ;;
            *) shift ;;
        esac
    done

    # Helper function for conditional output
    _omc_log() {
        [[ "$silent" != "true" ]] && echo -e "$@"
    }

    _omc_log "${BLUE}[OMC]${NC} Checking oh-my-claudecode version..."

    # Check if claude CLI exists
    if ! command -v claude &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Claude CLI not found"
        return 1
    fi

    # Get latest version from npm
    local LATEST_VERSION=$(npm view oh-my-claude-sisyphus version 2>/dev/null)
    if [[ -z "$LATEST_VERSION" ]]; then
        _omc_log "${YELLOW}[WARN]${NC} Could not fetch latest version from npm"
        LATEST_VERSION="unknown"
    fi

    # Get current installed version
    local PLUGIN_DIR="$HOME/.claude/plugins/cache/omc/oh-my-claudecode"
    local CURRENT_VERSION=""
    if [[ -d "$PLUGIN_DIR" ]]; then
        CURRENT_VERSION=$(ls "$PLUGIN_DIR" 2>/dev/null | sort -V | tail -1)
    fi

    _omc_log "${BLUE}[OMC]${NC} Current: ${CURRENT_VERSION:-none}, Latest: $LATEST_VERSION"

    # Check if update needed
    if [[ "$force" != "true" && -n "$CURRENT_VERSION" && "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
        # Check if build exists
        local PLUGIN_PATH="$PLUGIN_DIR/$CURRENT_VERSION"
        if [[ -f "$PLUGIN_PATH/dist/hud/index.js" ]]; then
            _omc_log "${GREEN}[OMC]${NC} Already up to date (v$CURRENT_VERSION)"

            # Still run setup if requested
            if [[ "$setup_after" == "true" ]]; then
                _omc_log "${YELLOW}[INFO]${NC} Start new Claude session and run: /oh-my-claudecode:omc-setup"
            fi
            return 0
        fi
    fi

    # From here on, always show output (update is happening)
    [[ "$silent" == "true" ]] && echo -e "${BLUE}[OMC]${NC} Update available: ${CURRENT_VERSION:-none} → $LATEST_VERSION"

    # Create .claude directory if not exists
    mkdir -p "$HOME/.claude"

    # Update CLAUDE.md
    echo -e "${BLUE}[OMC]${NC} Downloading latest CLAUDE.md..."
    if curl -fsSL "https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/docs/CLAUDE.md" -o "$HOME/.claude/CLAUDE.md"; then
        echo -e "${GREEN}[OK]${NC} CLAUDE.md updated"
    else
        echo -e "${YELLOW}[WARN]${NC} Could not download CLAUDE.md"
    fi

    # Update plugin
    echo -e "${BLUE}[OMC]${NC} Updating plugin..."
    if claude plugin update oh-my-claudecode 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC} Plugin updated"
    else
        echo -e "${YELLOW}[WARN]${NC} Plugin update failed (may need to install first)"
    fi

    # Build plugin (npm install triggers prepare script which runs build)
    # Re-check plugin version after update
    if [[ -d "$PLUGIN_DIR" ]]; then
        local PLUGIN_VERSION=$(ls "$PLUGIN_DIR" 2>/dev/null | sort -V | tail -1)
        if [[ -n "$PLUGIN_VERSION" ]]; then
            local PLUGIN_PATH="$PLUGIN_DIR/$PLUGIN_VERSION"
            if [[ ! -f "$PLUGIN_PATH/dist/hud/index.js" ]]; then
                echo -e "${BLUE}[OMC]${NC} Building plugin..."
                if (cd "$PLUGIN_PATH" && npm install --silent 2>/dev/null); then
                    echo -e "${GREEN}[OK]${NC} Plugin built"
                else
                    echo -e "${YELLOW}[WARN]${NC} Plugin build failed"
                fi
            else
                echo -e "${GREEN}[OK]${NC} Plugin already built"
            fi
        fi
    fi

    # Run setup if requested
    if [[ "$setup_after" == "true" ]]; then
        echo -e "${BLUE}[OMC]${NC} Running omc-setup..."
        echo -e "${YELLOW}[INFO]${NC} Start new Claude session and run: /oh-my-claudecode:omc-setup"
    fi

    echo -e "${GREEN}[OMC]${NC} Update complete!"
}
