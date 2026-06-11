#!/usr/bin/env bash
# install-homebrew.sh
# Install Homebrew on Linux (Linuxbrew) or macOS.
# Idempotent: skips if already installed.
#
# Usage:
#   bash ~/.dotfiles/install-homebrew.sh

set -euo pipefail

BREW_LINUX="/home/linuxbrew/.linuxbrew/bin/brew"
BREW_MAC="/opt/homebrew/bin/brew"

if command -v brew &>/dev/null; then
    echo "[OK] Homebrew already installed: $(brew --version | head -1)"
    exit 0
fi

if [[ -x "$BREW_LINUX" ]] || [[ -x "$BREW_MAC" ]]; then
    echo "[OK] Homebrew binary exists but not in PATH. Add shellenv to your shell config."
    exit 0
fi

echo "[*] Installing Homebrew..."

case "$(uname -s)" in
    Linux)
        # Install build dependencies
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -y
            sudo apt-get install -y build-essential procps curl file git
        elif command -v yum &>/dev/null; then
            sudo yum groupinstall -y 'Development Tools'
            sudo yum install -y procps-ng curl file git
        fi
        ;;
    Darwin)
        # Xcode CLI tools
        if ! xcode-select -p &>/dev/null; then
            xcode-select --install
            echo "[*] Waiting for Xcode CLI tools installation..."
            until xcode-select -p &>/dev/null; do sleep 5; done
        fi
        ;;
esac

NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Verify
if [[ -x "$BREW_LINUX" ]]; then
    eval "$($BREW_LINUX shellenv)"
elif [[ -x "$BREW_MAC" ]]; then
    eval "$($BREW_MAC shellenv)"
fi

echo "[OK] Homebrew installed: $(brew --version | head -1)"
