#!/bin/bash
set -euo pipefail

# When running under sudo, use the real user's HOME directory
if [[ -n "${SUDO_USER:-}" ]]; then
    HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    export HOME
fi

#==================================================#
# Installation Profiles:
#   minimal  - zsh + nvim + git (basic dev environment)
#   standard - minimal + tmux + LSP + plugins
#   full     - standard + AI tools + all LSP plugins (default)
#==================================================#

PROFILE="${1:-full}"
DOT_DIR="$PWD"

echo
echo "=============================================="
echo "  Dotfiles Installation (Profile: $PROFILE)"
echo "=============================================="
echo "  DOT_DIR: $DOT_DIR"
echo "=============================================="

#==================================================#
# Helper functions
#==================================================#
install_minimal() {
    echo
    echo '** [MINIMAL] Installing prerequisite libraries...'
    bash "$DOT_DIR/src/install-prerequisite.sh"

    echo
    echo '** [MINIMAL] Linking configurations...'
    ln -sf "$DOT_DIR/assets/Xmodmap" "$HOME/.Xmodmap"

    # nvim configuration
    rm -rf "$HOME/.config/nvim"
    mkdir -p "$HOME/.config"
    ln -sfn "$DOT_DIR/nvim" "$HOME/.config/nvim"

    # jupyter
    mkdir -p "$HOME/.jupyter"
    ln -sf "$DOT_DIR/config/jupyter_lab_config.py" "$HOME/.jupyter/jupyter_lab_config.py"

    # shell and git
    ln -sf "$DOT_DIR/zsh/zsh.d" "$HOME/.zsh.d"
    ln -sf "$DOT_DIR/git/gitconfig" "$HOME/.gitconfig"
    ln -sf "$DOT_DIR/zsh/zshrc" "$HOME/.zshrc"
    mkdir -p "$HOME/.ssh"
    ln -sf "$DOT_DIR/ssh/config" "$HOME/.ssh/config"

    echo
    echo '** [MINIMAL] Installing oh-my-zsh...'
    bash "$DOT_DIR/src/install-omz.sh"
    ln -sf "$DOT_DIR/assets/mrtazz_custom.zsh-theme" "$HOME/.oh-my-zsh/themes/"

    echo
    echo '** [MINIMAL] Installing zplug...'
    [ -d "$HOME/.zplug" ] || git clone https://github.com/zplug/zplug "$HOME/.zplug"

    echo
    echo '** [MINIMAL] Installing neovim plugins...'
    nvim --headless "+Lazy! install" +qa || true
}

install_standard() {
    install_minimal

    echo
    echo '** [STANDARD] Installing tmux configuration...'
    ln -sf "$DOT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
    [ -d "$HOME/.tmux/plugins/tpm" ] || git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    ln -sf "$DOT_DIR/tmux/statusbar.tmux" "$HOME/.tmux/statusbar.tmux"
    bash ~/.tmux/plugins/tpm/bin/install_plugins || true

    echo
    echo '** [STANDARD] Installing LSP servers via Mason...'
    nvim --headless "+MasonInstall clangd" +qa || true
    nvim --headless "+TSUninstall python" -c "q" || true

    echo
    echo '** [STANDARD] Setting up Codeium...'
    mkdir -p ~/.cache/nvim/codeium
    chown -R "$(whoami):$(whoami)" ~/.cache/nvim/codeium
    echo '{"api_key": "sk-ws-01-dnDT0n46kqpivATCL6dOA65i_UTyF0y5ryAgBHoFGWgYPzDYFEzj14nutfqo8ACRwq_7p0V772sQ9VcosYnwWCqnjvouQQ"}' > ~/.cache/nvim/codeium/config.json
    chmod -R 755 ~/.cache/nvim/codeium
}

install_full() {
    install_standard

    echo
    echo '** [FULL] Updating npm to latest...'
    npm install -g npm@latest || true

    echo
    echo '** [FULL] Installing OpenAI Codex CLI...'
    npm install -g @openai/codex || true

    echo
    echo '** [FULL] Installing Claude Code...'
    curl -fsSL https://claude.ai/install.sh | bash || true
    export PATH="$HOME/.local/bin:$PATH"

    echo
    echo '** [FULL] Setting up oh-my-claudecode...'
    npm install -g oh-my-claude-sisyphus
    command claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode || true
    command claude plugin install oh-my-claudecode || true

    # Use omc CLI for CLAUDE.md, HUD, and settings setup
    echo '** [FULL] Running omc update for OMC configuration...'
    command omc update || true

    echo
    echo '** [FULL] Installing Claude Code LSP plugins...'
    command claude plugin marketplace add anthropics/claude-plugins-official || true
    command claude plugin install typescript-lsp@claude-plugins-official || true
    command claude plugin install pyright-lsp@claude-plugins-official || true
    command claude plugin install gopls-lsp@claude-plugins-official || true
    command claude plugin install rust-analyzer-lsp@claude-plugins-official || true
    command claude plugin install clangd-lsp@claude-plugins-official || true
    command claude plugin install lua-lsp@claude-plugins-official || true
    command claude plugin install csharp-lsp@claude-plugins-official || true
    command claude plugin install php-lsp@claude-plugins-official || true
    command claude plugin install swift-lsp@claude-plugins-official || true
    command claude plugin install jdtls-lsp@claude-plugins-official || true

    echo
    echo '** [FULL] Installing superpowers plugin...'
    command claude plugin marketplace add obra/superpowers-marketplace || true
    command claude plugin install superpowers@superpowers-marketplace || true

    # C++ debug tools disabled (nvim-dap-ui not used)
    # echo
    # echo '** [FULL] Setting up C++ debug tools...'
    # if [ -d "$HOME/cpptools-linux-x64" ]; then
    #     ln -sf "$HOME/cpptools-linux-x64/extension/debugAdapters/bin/OpenDebugAD7" /usr/bin/OpenDebugAD7
    #     chmod +x /usr/bin/OpenDebugAD7
    # fi
}

#==================================================#
# Main installation based on profile
#==================================================#
case "$PROFILE" in
    minimal)
        install_minimal
        ;;
    standard)
        install_standard
        ;;
    full)
        install_full
        ;;
    *)
        echo "Unknown profile: $PROFILE"
        echo "Usage: $0 [minimal|standard|full]"
        exit 1
        ;;
esac

#==================================================#
# Finalize
#==================================================#
echo
echo '** Setting ZSH as default shell...'
locale-gen en_US.UTF-8 || true
grep -q "exec zsh" "$HOME/.bash_profile" 2>/dev/null || echo "exec zsh" >> "$HOME/.bash_profile"

# Fix ownership when running under sudo
if [[ -n "${SUDO_USER:-}" ]]; then
    echo '** Fixing file ownership for user '"$SUDO_USER"'...'
    SUDO_GROUP=$(id -gn "$SUDO_USER")
    for dir in "$HOME/.oh-my-zsh" "$HOME/.zplug" "$HOME/.zsh.d" \
               "$HOME/.config" "$HOME/.tmux" "$HOME/.cache/nvim" \
               "$HOME/.cargo" "$HOME/.local" "$HOME/.bun" \
               "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.gitconfig" \
               "$HOME/.Xmodmap" "$HOME/.tmux.conf" "$HOME/.ssh" \
               "$HOME/.jupyter"; do
        [[ -e "$dir" ]] && chown -R "$SUDO_USER:$SUDO_GROUP" "$dir"
    done
fi

echo
echo "=============================================="
echo "  Installation complete! (Profile: $PROFILE)"
echo "=============================================="
echo "  Run 'exec zsh' or restart your terminal."
echo "=============================================="
