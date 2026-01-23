#!/bin/bash
# Remove all dotfiles symlinks and installed components

echo "Cleaning up dotfiles installation..."

# Shell
rm -rf "$HOME/.oh-my-zsh"
rm -rf "$HOME/.zplug"
rm -rf "$HOME/.zshrc"
rm -rf "$HOME/.zsh.d"

# Git
rm -rf "$HOME/.gitconfig"
rm -rf "$HOME/.gitconfig.secret"

# Tmux
rm -rf "$HOME/.tmux.conf"
rm -rf "$HOME/.tmux/plugins/tpm"
rm -rf "$HOME/.tmux/statusbar.tmux"

# Neovim
rm -rf "$HOME/.config/nvim"
rm -rf "$HOME/.local/share/nvim"
rm -rf "$HOME/.local/state/nvim"
rm -rf "$HOME/.cache/nvim"

# Legacy vim
rm -rf "$HOME/.vimrc"
rm -rf "$HOME/.vim"

# SSH
rm -rf "$HOME/.ssh/config"

# Misc
rm -rf "$HOME/.Xmodmap"
rm -rf "$HOME/.fzf"*
rm -rf "$HOME/.aliases"

# Claude Code (optional - commented out by default)
# rm -rf "$HOME/.claude"

# Cpptools (downloaded by install-prerequisite.sh)
# rm -rf "$HOME/cpptools-linux-x64"

echo "Cleanup complete!"
