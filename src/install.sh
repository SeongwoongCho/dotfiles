#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n** %s\n' "$1"; }

DOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_AVANTE=false

while getopts 'i' flag; do
    case "${flag}" in
        i) INSTALL_AVANTE=true ;;
        *)
            echo "Usage: $(basename "$0") [-i]" >&2
            exit 1
            ;;
    esac
done

log "DOT_DIR: $DOT_DIR"

# Toggle Avante plugin
AVANTE_PATH="$DOT_DIR/lua/plugins/avante.lua"
AVANTE_BACKUP="${AVANTE_PATH}.old"
if $INSTALL_AVANTE; then
    if [ -f "$AVANTE_PATH" ]; then
        mv -f "$AVANTE_PATH" "$AVANTE_BACKUP"
    fi
else
    if [ -f "$AVANTE_BACKUP" ]; then
        mv -f "$AVANTE_BACKUP" "$AVANTE_PATH"
    fi
fi

log "download prerequisite libraries."
bash "$DOT_DIR/src/install-prerequisite.sh"

log "link custom configurations."
if [ -f "$DOT_DIR/aliases/misc" ]; then
    # shellcheck source=/dev/null
    source "$DOT_DIR/aliases/misc"
fi
ln -sf "$DOT_DIR/assets/Xmodmap" "$HOME/.Xmodmap"

rm -rf "$HOME/.config/nvim"
mkdir -p "$HOME/.config"
ln -sfn "$DOT_DIR" "$HOME/.config/nvim"

ln -sf "$DOT_DIR/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOT_DIR/aliases" "$HOME/.aliases"
ln -sf "$DOT_DIR/gitconfig" "$HOME/.gitconfig"
ln -sf "$DOT_DIR/zshrc" "$HOME/.zshrc"
ln -sf "$DOT_DIR/coc-settings.json" "$HOME/.config/nvim/coc-settings.json"

log "download oh-my-zsh."
bash "$DOT_DIR/src/install-omz.sh"
ln -sf "$DOT_DIR/assets/mrtazz_custom.zsh-theme" "$HOME/.oh-my-zsh/themes/"

log "download zsh plugin manager, zplug."
if [ ! -d "$HOME/.zplug" ]; then
    git clone https://github.com/zplug/zplug "$HOME/.zplug"
fi

mkdir -p ~/.cache/nvim/codeium
chown -R "$(whoami)":"$(whoami)" ~/.cache/nvim/codeium
chmod -R 755 ~/.cache/nvim/codeium
rm -f ~/.cache/nvim/codeium/config.json
echo '{"api_key": "sk-ws-01-dnDT0n46kqpivATCL6dOA65i_UTyF0y5ryAgBHoFGWgYPzDYFEzj14nutfqo8ACRwq_7p0V772sQ9VcosYnwWCqnjvouQQ"}' >>~/.cache/nvim/codeium/config.json

log "download neovim plugins from lazy.nvim."
nvim --headless "+Lazy! install" +qa
uv pip install --system pylatexenc
nvim --headless "+TSUpdateSync lua c cpp markdown markdown_inline latex html bash diff luadoc query vim vimdoc" -c "q"

# coc setup
## :call coc#util#install()
# cd ~/.local/share/nvim/lazy/coc.nvim/
# npm install
# cd $DOT_DIR
# nvim --headless "+CocInstall -sync coc-clangd" +qa

nvim --headless "MasonInstall clangd" +qa

ln -sf "$DOT_DIR/cpptools-linux-x64/extension/debugAdapters/bin/OpenDebugAD7" /usr/bin/OpenDebugAD7
chmod +x /usr/bin/OpenDebugAD7
nvim --headless "+TSUninstall python" -c "q"

npm install -g @anthropic-ai/claude-code
claude mcp add sequential-thinking npx -- -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add apidog -- npx -y apidog-mcp-server@latest --oas=https://petstore.swagger.io/v2/swagger.json
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
claude mcp add server-filesystem-- npx -- -y @modelcontextprotocol/server-filesystem
npm i -g @openai/codex

log "set ZSH as default shell."
locale-gen en_US.UTF-8
if ! grep -qs "exec zsh" "$HOME/.bash_profile"; then
    echo "exec zsh" >>"$HOME/.bash_profile"
fi
exec zsh
