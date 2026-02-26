#!/bin/bash
set -euo pipefail

#==================================================#
# Fetch and install secrets from private GitLab repo
#
# Usage:
#   bash src/install-secrets.sh          # fetch & install
#   bash src/install-secrets.sh --save   # collect & push
#
# Repo: Create a private repo on GitLab first:
#   https://git.mobilint.com/projects/new
#==================================================#

SECRETS_REPO="${DOTFILES_SECRETS_REPO:-git@github.com:SeongwoongCho/dotfiles-secret.git}"
SECRETS_DIR="${HOME}/dotfiles-secret"

#==================================================#
# Color
#==================================================#
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#==================================================#
# Secret file mapping
# Format: "path_in_repo:destination:permissions"
#
# Add new secrets here:
#==================================================#
SECRET_MAP=(
    "config/glab-cli/config.yml:${HOME}/.config/glab-cli/config.yml:600"
    "git/gitconfig.secret:${HOME}/.gitconfig.secret:600"
)

#==================================================#
# Fetch: clone or pull secrets repo
#==================================================#
fetch_secrets() {
    if [[ -d "$SECRETS_DIR/.git" ]]; then
        log_info "Updating secrets repository..."
        if git -C "$SECRETS_DIR" pull --quiet 2>/dev/null; then
            log_success "Secrets updated"
        else
            log_warn "Could not update secrets (offline?)"
        fi
    else
        log_info "Cloning secrets from $SECRETS_REPO ..."
        if git clone --quiet "$SECRETS_REPO" "$SECRETS_DIR" 2>/dev/null; then
            log_success "Secrets repository cloned"
        else
            log_warn "Could not clone secrets repository"
            log_info "Create the repo first, then run: bash src/install-secrets.sh --save"
            return 1
        fi
    fi
    return 0
}

#==================================================#
# Install: copy secrets to their destinations
#==================================================#
install_secrets() {
    local installed=0
    for entry in "${SECRET_MAP[@]}"; do
        IFS=':' read -r src dest perms <<< "$entry"
        if [[ -f "$SECRETS_DIR/$src" ]]; then
            mkdir -p "$(dirname "$dest")"
            cp "$SECRETS_DIR/$src" "$dest"
            chmod "$perms" "$dest"
            log_success "Installed: $dest"
            installed=$((installed + 1))
        fi
    done
    if [[ $installed -eq 0 ]]; then
        log_warn "No secret files found in repository"
    fi
}

#==================================================#
# Save: collect local secrets and push to repo
#==================================================#
save_secrets() {
    # Initialize repo if needed
    if [[ ! -d "$SECRETS_DIR/.git" ]]; then
        log_info "Initializing secrets repository..."
        mkdir -p "$SECRETS_DIR"
        git -C "$SECRETS_DIR" init --quiet
        git -C "$SECRETS_DIR" remote add origin "$SECRETS_REPO" 2>/dev/null || true
    fi

    # Collect secret files
    local collected=0
    for entry in "${SECRET_MAP[@]}"; do
        IFS=':' read -r src dest perms <<< "$entry"
        if [[ -f "$dest" ]]; then
            mkdir -p "$SECRETS_DIR/$(dirname "$src")"
            cp "$dest" "$SECRETS_DIR/$src"
            chmod "$perms" "$SECRETS_DIR/$src"
            log_success "Collected: $dest -> $src"
            collected=$((collected + 1))
        else
            log_warn "Not found: $dest (skipping)"
        fi
    done

    if [[ $collected -eq 0 ]]; then
        log_warn "No secret files found to save"
        return 1
    fi

    # Commit and push
    cd "$SECRETS_DIR"
    git add -A
    if git diff --cached --quiet 2>/dev/null; then
        log_info "No changes to push"
    else
        git commit --quiet -m "Update secrets $(date +%Y-%m-%d_%H:%M)"
        if git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null; then
            log_success "Secrets pushed to $SECRETS_REPO"
        else
            log_error "Push failed. Make sure the remote repo exists and you have access."
            log_info "Create it at: https://git.mobilint.com/projects/new"
            return 1
        fi
    fi
}

#==================================================#
# Main
#==================================================#
main() {
    case "${1:-}" in
        --save)
            echo '** Saving secrets to private repository...'
            save_secrets
            ;;
        *)
            echo '** Installing secrets from private repository...'
            if fetch_secrets; then
                install_secrets
            fi
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
