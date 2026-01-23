#!/bin/bash
#==================================================#
# Dotfiles Package Versions
#
# This file defines default versions for all packages.
# Override per-environment in config/versions.d/
#==================================================#

#-------------------------------------------------#
# System Info (auto-detected)
#-------------------------------------------------#
export DOTFILES_OS="${DOTFILES_OS:-$(uname -s)}"
export DOTFILES_ARCH="${DOTFILES_ARCH:-$(uname -m)}"

# Detect Ubuntu/Debian version
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    export DOTFILES_DISTRO="${ID:-unknown}"
    export DOTFILES_DISTRO_VERSION="${VERSION_ID:-unknown}"
    export DOTFILES_DISTRO_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"
else
    export DOTFILES_DISTRO="unknown"
    export DOTFILES_DISTRO_VERSION="unknown"
    export DOTFILES_DISTRO_CODENAME="unknown"
fi

# Detect Python version
if command -v python3 &>/dev/null; then
    export DOTFILES_PYTHON_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
else
    export DOTFILES_PYTHON_VERSION="unknown"
fi

#-------------------------------------------------#
# Core Tools
#-------------------------------------------------#
export VERSION_NEOVIM="${VERSION_NEOVIM:-v0.11.3}"
export VERSION_LUA="${VERSION_LUA:-5.1.5}"
export VERSION_LUAROCKS="${VERSION_LUAROCKS:-3.11.1}"
export VERSION_NODE="${VERSION_NODE:-20}"  # Major version for NodeSource

#-------------------------------------------------#
# Rust/Cargo Packages
#-------------------------------------------------#
export VERSION_TREE_SITTER="${VERSION_TREE_SITTER:-latest}"
export VERSION_GIT_DELTA="${VERSION_GIT_DELTA:-latest}"
export VERSION_EZA="${VERSION_EZA:-latest}"
export VERSION_DU_DUST="${VERSION_DU_DUST:-latest}"
export VERSION_AST_GREP="${VERSION_AST_GREP:-latest}"

#-------------------------------------------------#
# Python Packages (via uv/pip)
#-------------------------------------------------#
export VERSION_PYNVIM="${VERSION_PYNVIM:-latest}"
export VERSION_GPUSTAT="${VERSION_GPUSTAT:-latest}"
export VERSION_PRE_COMMIT="${VERSION_PRE_COMMIT:-latest}"
export VERSION_BLACK="${VERSION_BLACK:-latest}"
export VERSION_ISORT="${VERSION_ISORT:-latest}"
export VERSION_THEFUCK="${VERSION_THEFUCK:-latest}"
export VERSION_THEFUCK_PYTHON="${VERSION_THEFUCK_PYTHON:-3.11}"  # thefuck needs specific python

#-------------------------------------------------#
# Development Tools
#-------------------------------------------------#
export VERSION_VSCODE_CPPTOOLS="${VERSION_VSCODE_CPPTOOLS:-v1.24.1}"

#-------------------------------------------------#
# Load Environment-Specific Overrides
#-------------------------------------------------#
VERSIONS_DIR="${MYDOTFILES:-$HOME/.dotfiles}/config/versions.d"

# Load by distro + version (e.g., ubuntu-22.04.sh)
if [[ -f "$VERSIONS_DIR/${DOTFILES_DISTRO}-${DOTFILES_DISTRO_VERSION}.sh" ]]; then
    source "$VERSIONS_DIR/${DOTFILES_DISTRO}-${DOTFILES_DISTRO_VERSION}.sh"
fi

# Load by codename (e.g., jammy.sh, noble.sh)
if [[ -f "$VERSIONS_DIR/${DOTFILES_DISTRO_CODENAME}.sh" ]]; then
    source "$VERSIONS_DIR/${DOTFILES_DISTRO_CODENAME}.sh"
fi

# Load local overrides (not tracked by git)
if [[ -f "$VERSIONS_DIR/local.sh" ]]; then
    source "$VERSIONS_DIR/local.sh"
fi

#-------------------------------------------------#
# Version Info Display
#-------------------------------------------------#
print_version_info() {
    echo "=== Dotfiles Version Configuration ==="
    echo "System:"
    echo "  OS:           $DOTFILES_OS ($DOTFILES_ARCH)"
    echo "  Distro:       $DOTFILES_DISTRO $DOTFILES_DISTRO_VERSION ($DOTFILES_DISTRO_CODENAME)"
    echo "  Python:       $DOTFILES_PYTHON_VERSION"
    echo ""
    echo "Package Versions:"
    echo "  Neovim:       $VERSION_NEOVIM"
    echo "  Lua:          $VERSION_LUA"
    echo "  Luarocks:     $VERSION_LUAROCKS"
    echo "  Node:         $VERSION_NODE.x"
    echo "  VSCode C++:   $VERSION_VSCODE_CPPTOOLS"
    echo "  thefuck py:   $VERSION_THEFUCK_PYTHON"
    echo "======================================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_version_info
fi
