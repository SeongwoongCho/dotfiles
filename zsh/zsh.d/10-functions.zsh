#!/bin/zsh
# Utility functions

# fix-dns: Fix slow DNS resolution in Docker containers
# Usage: fix-dns [--check] [--force]
#   --check: Only diagnose, don't fix
#   --force: Apply fix without confirmation
function fix-dns() {
    local check_only=false
    local force=false
    local GREEN='\033[0;32m' YELLOW='\033[1;33m' RED='\033[0;31m' BLUE='\033[0;34m' NC='\033[0m'

    for arg in "$@"; do
        case "$arg" in
            --check) check_only=true ;;
            --force) force=true ;;
            -h|--help)
                echo "fix-dns: Fix slow DNS resolution in Docker containers"
                echo ""
                echo "Usage: fix-dns [--check] [--force]"
                echo "  --check  Only diagnose DNS latency, don't fix"
                echo "  --force  Apply fix without confirmation"
                echo ""
                echo "Adds Google DNS (8.8.8.8) to /etc/resolv.conf if DNS is slow"
                return 0
                ;;
        esac
    done

    # Measure DNS latency
    echo -ne "${BLUE}[DNS]${NC} Measuring DNS latency... "
    local dns_time=$(curl -w "%{time_namelookup}" -o /dev/null -s https://api.anthropic.com 2>/dev/null)

    if [[ -z "$dns_time" ]]; then
        echo -e "${RED}failed${NC} (curl error)"
        return 1
    fi

    # Convert to milliseconds for display
    local dns_ms=$(echo "$dns_time * 1000" | bc 2>/dev/null || echo "$dns_time")
    echo -e "${dns_time}s (${dns_ms}ms)"

    # Check if DNS is slow (threshold: 1 second)
    local is_slow=$(echo "$dns_time > 1.0" | bc 2>/dev/null)
    if [[ "$is_slow" != "1" ]]; then
        echo -e "${GREEN}[DNS]${NC} DNS resolution is fast (<1s). No fix needed."
        return 0
    fi

    echo -e "${YELLOW}[DNS]${NC} DNS resolution is slow (>1s)."

    if [[ "$check_only" == "true" ]]; then
        echo -e "${BLUE}[DNS]${NC} Run 'fix-dns' (without --check) to apply fix."
        return 0
    fi

    # Check if already has Google DNS
    if grep -q "^nameserver 8.8.8.8" /etc/resolv.conf 2>/dev/null; then
        echo -e "${YELLOW}[DNS]${NC} Google DNS (8.8.8.8) already configured but still slow."
        echo -e "${BLUE}[DNS]${NC} Consider checking network connectivity."
        return 1
    fi

    # Confirm before applying
    if [[ "$force" != "true" ]]; then
        echo -ne "${YELLOW}[DNS]${NC} Add Google DNS (8.8.8.8) to /etc/resolv.conf? [y/N] "
        read -r response
        [[ "$response" != [yY] ]] && { echo "Cancelled."; return 0; }
    fi

    # Apply fix (requires root)
    if [[ $EUID -ne 0 ]]; then
        echo -e "${BLUE}[DNS]${NC} Applying fix with sudo..."
        echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null
    else
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
    fi

    # Verify fix
    echo -ne "${BLUE}[DNS]${NC} Verifying... "
    local new_dns_time=$(curl -w "%{time_namelookup}" -o /dev/null -s https://api.anthropic.com 2>/dev/null)
    echo -e "${new_dns_time}s"

    local is_fixed=$(echo "$new_dns_time < 1.0" | bc 2>/dev/null)
    if [[ "$is_fixed" == "1" ]]; then
        echo -e "${GREEN}[DNS]${NC} DNS resolution fixed! (${dns_time}s → ${new_dns_time}s)"
    else
        echo -e "${YELLOW}[DNS]${NC} DNS still slow. May need additional network configuration."
    fi
}

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

# =============================================================================
# Accelerator Device Selection Functions
# =============================================================================
# Device visibility control for hardware accelerators:
# - NVIDIA GPU:       CUDA_VISIBLE_DEVICES
# - Intel Gaudi/HPU:  HABANA_VISIBLE_DEVICES
# - Mobilint NPU:     MACCEL_VISIBLE_DEVICES
#
# Short aliases: ug (GPU), uh (HPU), um (Mobilint NPU)
# Selected devices are displayed in the shell prompt (see zsh-theme).
# =============================================================================

# GPU device selection (NVIDIA CUDA)
# Usage: ug [device_ids]
#   ug 0      - Use GPU 0 only
#   ug 0,1    - Use GPUs 0 and 1
#   ug        - Clear selection (use all available)
function usegpu() {
    if [ -n "$1" ]; then
        export CUDA_VISIBLE_DEVICES="$1"
    else
        unset CUDA_VISIBLE_DEVICES
    fi
}
alias ug='usegpu'

# HPU device selection (Intel Gaudi / Habana)
# Usage: uh [device_ids]
#   uh 0      - Use HPU 0 only
#   uh 0,1    - Use HPUs 0 and 1
#   uh        - Clear selection (use all available)
function usehpu() {
    if [ -n "$1" ]; then
        export HABANA_VISIBLE_DEVICES="$1"
    else
        unset HABANA_VISIBLE_DEVICES
    fi
}
alias uh='usehpu'

# Mobilint NPU device selection
# Usage: um [device_ids]
#   um 0      - Use NPU 0 only
#   um 0,1    - Use NPUs 0 and 1
#   um        - Clear selection (use all available)
#
# MACCEL_VISIBLE_DEVICES: Environment variable for Mobilint Inc. NPU accelerators.
# Similar to CUDA_VISIBLE_DEVICES, this controls which NPU devices are visible
# to Mobilint's runtime and frameworks.
function usemaccel() {
    if [ -n "$1" ]; then
        export MACCEL_VISIBLE_DEVICES="$1"
    else
        unset MACCEL_VISIBLE_DEVICES
    fi
}
alias um='usemaccel'

# PYTHONPATH setting
# Usage: up [path]
#   up .        - Set PYTHONPATH to current directory
#   up /path    - Set PYTHONPATH to specified path
#   up          - Clear PYTHONPATH
function up() {
    if [ -n "$1" ]; then
        if [ "$1" = "." ]; then
            export PYTHONPATH="$(pwd)"
        else
            export PYTHONPATH="$1"
        fi
    else
        unset PYTHONPATH
    fi
}

# Dotfiles Quick Reference
# Usage: dothelp [category]
#   dothelp         - Show all categories
#   dothelp alias   - Show aliases only
#   dothelp func    - Show functions only
#   dothelp key     - Show keybindings only
#   dothelp accel   - Show accelerator commands
function dothelp() {
    local CYAN='\033[0;36m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
    local MAGENTA='\033[0;35m' BLUE='\033[0;34m' BOLD='\033[1m'
    local DIM='\033[2m' NC='\033[0m'

    _header() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }
    _cmd() { printf "  ${GREEN}%-14s${NC} %s\n" "$1" "$2"; }
    _key() { printf "  ${YELLOW}%-14s${NC} %s\n" "$1" "$2"; }

    local show_all=true
    [[ -n "$1" ]] && show_all=false

    # Header
    echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║       ${CYAN}dotfiles Quick Reference${MAGENTA}         ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════╝${NC}"

    # Accelerator & Environment
    if [[ "$show_all" == true || "$1" == "accel" || "$1" == "env" ]]; then
        _header "Accelerator & Environment"
        _cmd "ug <ids>" "Set CUDA_VISIBLE_DEVICES (prompt: cuda:X)"
        _cmd "uh <ids>" "Set HABANA_VISIBLE_DEVICES (prompt: habana:X)"
        _cmd "um <ids>" "Set MACCEL_VISIBLE_DEVICES (prompt: maccel:X)"
        _cmd "up <path>" "Set PYTHONPATH (prompt: pypath:~)"
        _cmd "gpu" "Watch gpustat (NVIDIA)"
        _cmd "npu" "Watch npustat (Mobilint)"
        _cmd "hpusmi" "Watch hl-smi (Intel Gaudi)"
    fi

    # Common Aliases
    if [[ "$show_all" == true || "$1" == "alias" ]]; then
        _header "Common Aliases"
        _cmd "vim" "nvim"
        _cmd "ls" "eza (modern ls)"
        _cmd "cd" "zoxide (smart cd)"
        _cmd "bat" "batcat (syntax highlight)"
        _cmd "df" "duf (disk usage)"
        _cmd "jl / jla" "Jupyter Lab (local / all IPs)"
        _cmd "claude" "Claude Code (auto-updates OMC)"
    fi

    # Utility Functions
    if [[ "$show_all" == true || "$1" == "func" ]]; then
        _header "Utility Functions"
        _cmd "dotup" "Update dotfiles (git + plugins)"
        _cmd "dotup-full" "Full update (+ packages)"
        _cmd "dotcd" "cd to ~/.dotfiles"
        _cmd "omc update" "Update Oh-My-ClaudeCode"
        _cmd "fix-dns" "Fix slow DNS in Docker"
        _cmd "pyclean" "Remove __pycache__ files"
        _cmd "fuzzyvim" "Open file with fzf + vim"
        _cmd "howmany" "Count files matching pattern"
    fi

    # Neovim Keybindings
    if [[ "$show_all" == true || "$1" == "key" || "$1" == "vim" ]]; then
        _header "Neovim Keys (Leader: ,)"
        _key ",s" "Save file"
        _key ",R" "Reload config"
        _key "@" "Clear search highlight"
        _key "<C-p>" "Find files (Telescope)"
        _key "<C-o>" "Live grep"
        _key "[b / ]b" "Prev/Next buffer"
        _key ",g" "Go back (after goto-def)"
        _key "<F8>" "Toggle paste mode"
        _key "<F9>" "Toggle line numbers"
        _key "y / yy" "Yank to system clipboard"
        _key ",b / ,v" "Insert ipdb breakpoint"
    fi

    # Tmux Keybindings
    if [[ "$show_all" == true || "$1" == "key" || "$1" == "tmux" ]]; then
        _header "Tmux Keys (Prefix: Ctrl-A)"
        _key "v" "Vertical split (side by side)"
        _key "s" "Horizontal split (top/bottom)"
        _key "h/j/k/l" "Navigate panes"
        _key "c" "New window"
        _key "0-9" "Select window by number"
        _key "q" "Display pane numbers"
        _key "r" "Reload config"
        _key "e" "Toggle sync mode"
        _key "> / <" "Resize pane width"
        _key "+ / -" "Resize pane height"
        _key "Esc/Enter" "Enter copy mode"
    fi

    # Plugins
    if [[ "$show_all" == true || "$1" == "plugin" || "$1" == "plugins" ]]; then
        _header "Neovim Plugins (Lazy.nvim)"
        _cmd "telescope" "Fuzzy finder (<C-p>, <C-o>)"
        _cmd "nvim-cmp" "Autocompletion"
        _cmd "treesitter" "Syntax highlighting"
        _cmd "gitsigns" "Git integration"
        _cmd "codeium" "AI code completion"
        _cmd "nvim-tree" "File explorer"
        _cmd "barbar" "Buffer tabs"
        _cmd "mason" "LSP auto-installer"

        _header "Zsh Plugins (zplug)"
        _cmd "alias-tips" "Shows alias hints"
        _cmd "syntax-hl" "Command highlighting"
        _cmd "autosugg" "Fish-like suggestions"
        _cmd "fzf + fd" "Fuzzy file finding"
        _cmd "zoxide" "Smart cd (z command)"

        _header "Tmux Plugins (TPM)"
        _cmd "resurrect" "Session save/restore"
        _cmd "continuum" "Auto save sessions"
        _cmd "extrakto" "Text extraction (prefix+tab)"
    fi

    # Footer
    echo -e "\n${DIM}Usage: dothelp [alias|func|key|accel|vim|tmux|plugin]${NC}"
    echo -e "${DIM}Full docs: cat ~/.dotfiles/README.md${NC}"
}
