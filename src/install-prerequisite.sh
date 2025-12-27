#!/bin/bash

#####################################
# Color Definitions
#####################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Track failures
declare -a FAILED_PACKAGES=()

#####################################
# Logging Functions
#####################################
log_section() {
    echo -e "\n${MAGENTA}${BOLD}═══════════════════════════════════════${NC}"
    echo -e "${MAGENTA}${BOLD}  $1${NC}"
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════${NC}"
}

log_install() { echo -e "${CYAN}[INSTALLING]${NC} $1 via ${BOLD}$2${NC}..."; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1 installed via $2"; }
log_warn() { echo -e "${YELLOW}[FALLBACK]${NC} $1: $2"; }
log_error() {
    echo -e "${RED}[FAILED]${NC} $1 via $2"
    FAILED_PACKAGES+=("$1 ($2)")
}
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1 already installed"; }

#####################################
# Installation Helper Functions
#####################################

install_by_apt() {
    local pkg="$1"
    log_install "$pkg" "apt"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1; then
        log_success "$pkg" "apt"
        return 0
    else
        log_error "$pkg" "apt"
        return 1
    fi
}

install_by_cargo() {
    local pkg="$1"
    local use_locked="${2:-true}"

    # Check if already installed
    if cargo install --list 2>/dev/null | grep -q "^$pkg "; then
        log_skip "$pkg"
        return 0
    fi

    log_install "$pkg" "cargo"
    local args=""
    [[ "$use_locked" == "true" ]] && args="--locked"

    if cargo install $args "$pkg" >/dev/null 2>&1; then
        log_success "$pkg" "cargo"
        return 0
    else
        log_error "$pkg" "cargo"
        return 1
    fi
}

install_by_uv() {
    local pkg="$1"
    shift

    # Parse options
    local editable=false
    local pkg_path=""
    local python_version=""
    local with_deps=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --editable)
            editable=true
            pkg_path="$2"
            shift 2
            ;;
        --python)
            python_version="$2"
            shift 2
            ;;
        --with)
            with_deps="$2"
            shift 2
            ;;
        *) shift ;;
        esac
    done

    # For editable installs, skip uv tool, go straight to pip methods
    if [[ "$editable" == "true" ]]; then
        log_install "$pkg" "uv pip --system -e"
        if uv pip install --system -e "$pkg_path" >/dev/null 2>&1; then
            log_success "$pkg" "uv pip --system -e"
            return 0
        fi
        log_warn "$pkg" "Trying pip install -e..."
        if pip install -e "$pkg_path" >/dev/null 2>&1; then
            log_success "$pkg" "pip -e"
            return 0
        fi
        log_error "$pkg" "pip -e"
        return 1
    fi

    # Build uv tool install command
    local uv_args=("$pkg")
    [[ -n "$python_version" ]] && uv_args+=("--python" "$python_version")
    [[ -n "$with_deps" ]] && uv_args+=("--with" "$with_deps")

    local method="uv tool"
    [[ -n "$python_version" ]] && method="uv tool (python $python_version)"

    # Try 1: uv tool install
    log_install "$pkg" "$method"
    if uv tool install "${uv_args[@]}" >/dev/null 2>&1; then
        log_success "$pkg" "$method"
        return 0
    fi

    # Try 2: uv pip install --system (only if no special options)
    if [[ -z "$python_version" && -z "$with_deps" ]]; then
        log_warn "$pkg" "Trying uv pip --system..."
        if uv pip install --system "$pkg" >/dev/null 2>&1; then
            log_success "$pkg" "uv pip --system"
            return 0
        fi

        # Try 3: pip install
        log_warn "$pkg" "Trying pip install..."
        if pip install "$pkg" >/dev/null 2>&1; then
            log_success "$pkg" "pip"
            return 0
        fi
    fi

    log_error "$pkg" "all methods"
    return 1
}

install_by_script() {
    local pkg="$1"
    local url="$2"
    local post_cmd="${3:-}"

    log_install "$pkg" "script"
    if curl -sSfL "$url" 2>/dev/null | sh >/dev/null 2>&1; then
        [[ -n "$post_cmd" ]] && eval "$post_cmd"
        log_success "$pkg" "script"
        return 0
    fi
    log_error "$pkg" "script"
    return 1
}

#####################################
# Custom Install Functions
#####################################

install_rust() {
    if command -v cargo >/dev/null 2>&1; then
        log_skip "rust/cargo"
        return 0
    fi
    log_install "rust" "rustup"
    if curl https://sh.rustup.rs -sSf | sh -s -- -y >/dev/null 2>&1; then
        export PATH="$HOME/.cargo/bin:$PATH"
        log_success "rust" "rustup"
        return 0
    fi
    log_error "rust" "rustup"
    return 1
}

install_lua() {
    local version="${1:-5.1.5}"
    log_install "lua-$version" "source"
    local build_dir=$(mktemp -d)
    (
        cd "$build_dir"
        wget -q "http://www.lua.org/ftp/lua-$version.tar.gz"
        tar zxf "lua-$version.tar.gz"
        cd "lua-$version"
        make linux test >/dev/null 2>&1
        make install >/dev/null 2>&1
    )
    local ret=$?
    rm -rf "$build_dir"
    if [[ $ret -eq 0 ]]; then
        log_success "lua-$version" "source"
    else
        log_error "lua-$version" "source"
    fi
    return $ret
}

install_luarocks() {
    local version="${1:-3.11.1}"
    log_install "luarocks-$version" "source"
    local build_dir=$(mktemp -d)
    (
        cd "$build_dir"
        wget -q "https://luarocks.org/releases/luarocks-$version.tar.gz"
        tar zxpf "luarocks-$version.tar.gz"
        cd "luarocks-$version"
        ./configure >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1
    )
    local ret=$?
    rm -rf "$build_dir"
    if [[ $ret -eq 0 ]]; then
        log_success "luarocks-$version" "source"
        luarocks install luasocket >/dev/null 2>&1
    else
        log_error "luarocks-$version" "source"
    fi
    return $ret
}

install_neovim() {
    local version="${1:-v0.11.3}"
    log_install "neovim-$version" "source"

    # Install build dependencies
    DEBIAN_FRONTEND=noninteractive apt-get install -y ninja-build gettext cmake unzip curl build-essential >/dev/null 2>&1

    rm -rf ~/.neovim
    if git clone --depth 1 https://github.com/neovim/neovim -b "$version" ~/.neovim >/dev/null 2>&1; then
        (
            cd ~/.neovim
            CC=gcc CXX=g++ make CMAKE_BUILD_TYPE=RelWithDebInfo >/dev/null 2>&1
            make install >/dev/null 2>&1
        )
        if [[ $? -eq 0 ]]; then
            log_success "neovim-$version" "source"
            return 0
        fi
    fi
    log_error "neovim-$version" "source"
    return 1
}

install_vscode_cpptools() {
    local version="${1:-v1.24.1}"
    log_install "vscode-cpptools-$version" "github"
    local url="https://github.com/microsoft/vscode-cpptools/releases/download/$version/cpptools-linux-x64.vsix"
    local dest_dir="$HOME/cpptools-linux-x64"

    rm -rf "$dest_dir" cpptools-linux-x64.vsix
    if wget -q "$url" -O cpptools-linux-x64.vsix && unzip -q cpptools-linux-x64.vsix -d "$dest_dir"; then
        rm -f cpptools-linux-x64.vsix
        log_success "vscode-cpptools-$version" "github"
        return 0
    fi
    rm -f cpptools-linux-x64.vsix
    log_error "vscode-cpptools-$version" "github"
    return 1
}

install_mobilint() {
    log_install "mobilint-cli" "mobilint repo"

    # Add GPG key
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates >/dev/null 2>&1
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://dl.mobilint.com/apt/gpg.pub -o /etc/apt/keyrings/mblt.asc 2>/dev/null
    chmod a+r /etc/apt/keyrings/mblt.asc

    # Add repo
    printf "%s\n" \
        "deb [signed-by=/etc/apt/keyrings/mblt.asc] https://dl.mobilint.com/apt stable multiverse" \
        "deb [signed-by=/etc/apt/keyrings/mblt.asc] https://dl.mobilint.com/apt $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") multiverse" |
        tee /etc/apt/sources.list.d/mobilint.list >/dev/null

    apt-get update >/dev/null 2>&1
    if DEBIAN_FRONTEND=noninteractive apt-get install -y mobilint-cli >/dev/null 2>&1; then
        log_success "mobilint-cli" "mobilint repo"
        return 0
    fi
    log_error "mobilint-cli" "mobilint repo"
    return 1
}

install_kitty_magick() {
    log_install "kitty" "installer script"
    if curl -L https://sw.kovidgoyal.net/kitty/installer.sh 2>/dev/null | sh /dev/stdin >/dev/null 2>&1; then
        log_success "kitty" "installer script"
    else
        log_error "kitty" "installer script"
    fi

    log_install "magick" "luarocks"
    if luarocks --lua-version=5.1 install magick >/dev/null 2>&1; then
        log_success "magick" "luarocks"
    else
        log_error "magick" "luarocks"
    fi

    install_by_apt "imagemagick"
    install_by_apt "libmagickwand-dev"
}

#####################################
# Summary Function
#####################################

print_summary() {
    echo
    log_section "Installation Summary"
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All packages installed successfully!${NC}"
    else
        echo -e "${RED}${BOLD}✗ ${#FAILED_PACKAGES[@]} package(s) failed to install:${NC}"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo -e "  ${RED}- $pkg${NC}"
        done
    fi
    echo
}

#####################################
# Main Function
#####################################

main() {
    log_section "APT Repository Setup"
    apt-get update >/dev/null 2>&1
    install_by_apt "software-properties-common"
    install_by_apt "curl"
    add-apt-repository -y ppa:neovim-ppa/unstable >/dev/null 2>&1
    curl -s https://deb.nodesource.com/setup_20.x 2>/dev/null | bash >/dev/null 2>&1
    apt-get update >/dev/null 2>&1

    log_section "APT Packages"
    local apt_packages=(
        sudo python3-opencv aria2 gcc cmake libgl1 libglib2.0-0 g++ ccache nodejs
        unzip zip zsh ssh wget curl git htop rsync fzf
        tmux libevent-dev ncurses-dev bison locales chafa pkg-config build-essential libreadline-dev ripgrep fd-find
        clang-format clang clangd llvm libclang-dev libclang1 clangd-12 libomp-dev gdb
        python3-venv bat duf
    )
    for pkg in "${apt_packages[@]}"; do
        install_by_apt "$pkg"
    done

    log_section "Rust & Cargo"
    install_rust
    export PATH="$HOME/.cargo/bin:$PATH"

    log_section "Cargo Packages"
    install_by_cargo "tree-sitter-cli" true
    install_by_cargo "git-delta" false
    install_by_cargo "eza" false
    install_by_cargo "du-dust" false

    log_section "Custom Tools"
    install_by_script "shfmt" "https://webi.sh/shfmt" \
        '[[ -f ~/.config/envman/PATH.env ]] && source ~/.config/envman/PATH.env'
    install_by_script "zoxide" "https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh"

    log_section "Neovim"
    install_neovim "v0.11.3"

    log_section "Lua & Luarocks"
    install_lua "5.1.5"
    install_luarocks "3.11.1"

    log_section "Image Support (Kitty & Magick)"
    install_kitty_magick

    log_section "UV/Pip Setup"
    pip install uv >/dev/null 2>&1
    uv self update >/dev/null 2>&1 || true

    log_section "Python Packages"
    install_by_uv "pynvim"
    install_by_uv "isort"
    install_by_uv "gpustat"
    install_by_uv "npustat" --editable "$HOME/.dotfiles/npustat"
    install_by_uv "pre-commit"
    install_by_uv "black"
    install_by_uv "jedi_language_server"
    install_by_uv "python-lsp-server"
    install_by_uv "thefuck" --python 3.11 --with setuptools
    install_by_uv "maccel"
    install_by_uv "pylatexenc"

    log_section "VSCode C++ Tools"
    install_vscode_cpptools "v1.24.1"

    log_section "Mobilint"
    install_mobilint

    print_summary
}

main "$@"
