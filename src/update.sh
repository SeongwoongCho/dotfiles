#!/bin/bash
set -euo pipefail

#==================================================#
# Dotfiles Update Script
# Usage: update.sh [OPTIONS]
# Options:
#   --packages    Also reinstall/update system packages
#   --full        Run full update (packages + plugins)
#   --profile X   Specify profile (minimal/standard/full) for package updates
#==================================================#

DOT_DIR="${MYDOTFILES:-$HOME/.dotfiles}"
PROFILE="${DOTFILES_PROFILE:-full}"
UPDATE_PACKAGES=false

#==================================================#
# Load Version Configuration
#==================================================#
if [[ -f "$DOT_DIR/config/versions.sh" ]]; then
    source "$DOT_DIR/config/versions.sh"
fi

#==================================================#
# Color Definitions
#==================================================#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_section() {
    echo -e "\n${MAGENTA}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${MAGENTA}${BOLD}  $1${NC}"
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#==================================================#
# Parse Arguments
#==================================================#
while [[ $# -gt 0 ]]; do
    case "$1" in
        --packages)
            UPDATE_PACKAGES=true
            shift
            ;;
        --full)
            UPDATE_PACKAGES=true
            shift
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --versions)
            # Show version info and exit
            if declare -f print_version_info &>/dev/null; then
                print_version_info
            else
                log_error "Version config not loaded"
            fi
            exit 0
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --packages    Also reinstall/update system packages"
            echo "  --full        Alias for --packages"
            echo "  --profile X   Specify profile (minimal/standard/full)"
            echo "  --versions    Show current version configuration"
            echo "  -h, --help    Show this help"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

#==================================================#
# 1. Git Pull
#==================================================#
log_section "Pulling Latest Changes"

cd "$DOT_DIR"
CURRENT_BRANCH=$(git branch --show-current)
log_info "Current branch: $CURRENT_BRANCH"

# Stash any local changes
if ! git diff --quiet 2>/dev/null; then
    log_warn "Local changes detected, stashing..."
    git stash push -m "dotfiles-update-$(date +%Y%m%d-%H%M%S)"
fi

# Pull latest
if git pull origin "$CURRENT_BRANCH" 2>/dev/null; then
    log_success "Pulled latest changes from origin/$CURRENT_BRANCH"
else
    log_warn "Could not pull (maybe offline or no remote?)"
fi

# Show what changed
CHANGED_FILES=$(git diff --name-only HEAD@{1} HEAD 2>/dev/null || echo "")
if [[ -n "$CHANGED_FILES" ]]; then
    log_info "Changed files:"
    echo "$CHANGED_FILES" | sed 's/^/  - /'

    # Check if version files changed
    if echo "$CHANGED_FILES" | grep -q "config/versions"; then
        log_warn "Version configuration changed! Consider running with --packages"
    fi

    # Check if prerequisite script changed
    if echo "$CHANGED_FILES" | grep -q "install-prerequisite.sh"; then
        log_warn "Package installation script changed! Consider running with --packages"
    fi
fi

#==================================================#
# 2. Relink Symlinks
#==================================================#
log_section "Relinking Configurations"

link_if_needed() {
    local src="$1"
    local dest="$2"
    if [[ -e "$src" ]]; then
        ln -sf "$src" "$dest" && log_success "Linked: $dest -> $src"
    else
        log_warn "Source not found: $src"
    fi
}

link_dir_if_needed() {
    local src="$1"
    local dest="$2"
    if [[ -d "$src" ]]; then
        rm -rf "$dest"
        ln -sfn "$src" "$dest" && log_success "Linked dir: $dest -> $src"
    else
        log_warn "Source dir not found: $src"
    fi
}

# Core configs
link_if_needed "$DOT_DIR/assets/Xmodmap" "$HOME/.Xmodmap"
link_if_needed "$DOT_DIR/zsh/zshrc" "$HOME/.zshrc"
link_if_needed "$DOT_DIR/zsh/zsh.d" "$HOME/.zsh.d"
link_if_needed "$DOT_DIR/git/gitconfig" "$HOME/.gitconfig"
link_if_needed "$DOT_DIR/ssh/config" "$HOME/.ssh/config"
link_if_needed "$DOT_DIR/assets/mrtazz_custom.zsh-theme" "$HOME/.oh-my-zsh/themes/mrtazz_custom.zsh-theme"

# secrets (glab config, gitconfig.secret, etc.)
bash "$DOT_DIR/src/install-secrets.sh" || true

# Neovim
mkdir -p "$HOME/.config"
link_dir_if_needed "$DOT_DIR/nvim" "$HOME/.config/nvim"

# Tmux (if exists)
if [[ -f "$DOT_DIR/tmux/tmux.conf" ]]; then
    link_if_needed "$DOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
    mkdir -p "$HOME/.tmux"
    link_if_needed "$DOT_DIR/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux"
fi

#==================================================#
# 3. Update System Packages (optional)
#==================================================#
if [[ "$UPDATE_PACKAGES" == "true" ]]; then
    log_section "Updating System Packages"

    # Show version info before updating
    if declare -f print_version_info &>/dev/null; then
        print_version_info
    fi

    if [[ -f "$DOT_DIR/src/install-prerequisite.sh" ]]; then
        log_info "Running install-prerequisite.sh..."
        bash "$DOT_DIR/src/install-prerequisite.sh"
    else
        log_warn "install-prerequisite.sh not found"
    fi
fi

#==================================================#
# 4. Update Plugins
#==================================================#
log_section "Updating Plugins"

# Neovim plugins (Lazy.nvim)
if command -v nvim &>/dev/null; then
    log_info "Syncing Neovim plugins..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null && log_success "Neovim plugins synced" || log_warn "Neovim plugin sync had issues"
fi

# Tmux plugins (TPM)
if [[ -x "$HOME/.tmux/plugins/tpm/bin/update_plugins" ]]; then
    log_info "Updating tmux plugins..."
    "$HOME/.tmux/plugins/tpm/bin/update_plugins" all 2>/dev/null && log_success "Tmux plugins updated" || log_warn "Tmux plugin update had issues"
fi

# Zplug
if [[ -d "$HOME/.zplug" ]]; then
    log_info "Updating zplug plugins..."
    # zplug update needs to run in zsh
    zsh -c 'source ~/.zplug/init.zsh && zplug update' 2>/dev/null && log_success "Zplug plugins updated" || log_warn "Zplug update had issues"
fi

#==================================================#
# 5. Profile-specific updates
#==================================================#
if [[ "$PROFILE" == "full" ]]; then
    log_section "Full Profile Updates"

    # Update oh-my-claudecode CLAUDE.md
    if command -v claude &>/dev/null && [[ -d "$HOME/.claude" ]]; then
        log_info "Updating oh-my-claudecode CLAUDE.md..."
        curl -fsSL "https://raw.githubusercontent.com/Yeachan-Heo/oh-my-claudecode/main/docs/CLAUDE.md" -o ~/.claude/CLAUDE.md 2>/dev/null && \
            log_success "CLAUDE.md updated" || log_warn "Could not update CLAUDE.md"

        # Update OMC plugin
        log_info "Updating oh-my-claudecode plugin..."
        claude plugin update oh-my-claudecode 2>/dev/null && log_success "oh-my-claudecode updated" || log_warn "Could not update oh-my-claudecode"
    fi
fi

#==================================================#
# 6. Summary
#==================================================#
log_section "Update Complete"

echo -e "${GREEN}${BOLD}Dotfiles have been updated!${NC}"
echo ""
echo "To apply all changes to your current shell, run:"
echo -e "  ${CYAN}source ~/.zshrc${NC}  or  ${CYAN}exec zsh${NC}"
echo ""

if [[ -n "${TMUX:-}" ]]; then
    echo "To reload tmux config:"
    echo -e "  ${CYAN}tmux source-file ~/.tmux.conf${NC}"
    echo ""
fi

log_info "Tip: Run with --packages to also update system packages"
