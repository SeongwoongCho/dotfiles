#!/usr/bin/env bash
set -euo pipefail

targets=(
    "$HOME/.oh-my-zsh"
    "$HOME/.aliases"
    "$HOME/.tmux.conf"
    "$HOME/.gitconfig"
    "$HOME/.gitconfig.secret"
    "$HOME/.Xmodmap"
    "$HOME/.vimrc"
    "$HOME/.config/nvim"
    "$HOME/.local/share/nvim"
    "$HOME/.local/state/nvim"
    "$HOME/.vim"
    "$HOME/.zshrc"
    "$HOME/.fzf"*
)

for path in "${targets[@]}"; do
    rm -rf "$path"
done
