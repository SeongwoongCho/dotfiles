#! /bin/bash

#==================================================#
DOT_DIR=$PWD
echo
echo '** DOT_DIR: ' $DOT_DIR

#==================================================#
echo
echo '** download prerequisite libraries.'
bash $DOT_DIR/src/install-prerequisite.sh

#==================================================#
echo
echo '** link custom configurations.'
source "$PWD/zsh/zsh.d/misc.zsh"
ln -sf $DOT_DIR/assets/Xmodmap $HOME/.Xmodmap

# Clean and link nvim configuration
rm -rf $HOME/.config/nvim
mkdir -p $HOME/.config
ln -sfn $DOT_DIR/nvim $HOME/.config/nvim

ln -sf $DOT_DIR/tmux/tmux.conf $HOME/.tmux.conf
ln -sf $DOT_DIR/zsh/zsh.d $HOME/.zsh.d
ln -sf $DOT_DIR/git/gitconfig $HOME/.gitconfig
ln -sf $DOT_DIR/zsh/zshrc $HOME/.zshrc
ln -sf $DOT_DIR/ssh/config $HOME/.ssh/config

# #==================================================#
echo
echo '** download oh-my-zsh.'
bash $DOT_DIR/src/install-omz.sh
ln -sf $DOT_DIR/assets/mrtazz_custom.zsh-theme $HOME/.oh-my-zsh/themes/

#==================================================#
# download useful plugins
echo
echo '** download zsh plugin manager, zplug.'
git clone https://github.com/zplug/zplug $HOME/.zplug

# download tmux plugin manager (TPM)
echo
echo '** download tmux plugin manager (TPM).'
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
ln -sf $DOT_DIR/tmux/statusbar.tmux ~/.tmux/statusbar.tmux

# install tmux plugins via TPM (without entering tmux session)
echo
echo '** install tmux plugins.'
bash ~/.tmux/plugins/tpm/bin/install_plugins

# codeium
mkdir -p ~/.cache/nvim/codeium
chown -R $(whoami):$(whoami) ~/.cache/nvim/codeium
chmod -R 755 ~/.cache/nvim/codeium

# register codeium key automatically
rm -f ~/.cache/nvim/codeium/config.json
touch ~/.cache/nvim/codeium/config.json
echo '{"api_key": "sk-ws-01-dnDT0n46kqpivATCL6dOA65i_UTyF0y5ryAgBHoFGWgYPzDYFEzj14nutfqo8ACRwq_7p0V772sQ9VcosYnwWCqnjvouQQ"}' >>~/.cache/nvim/codeium/config.json
chmod -R 755 ~/.cache/nvim/codeium

#==================================================#
# download neovim plugins from lazy.nvim
nvim --headless "+Lazy! install" +qa
nvim --headless "+MasonInstall clangd" +qa

# vscode symlink
ln -sf $DOT_DIR/cpptools-linux-x64/extension/debugAdapters/bin/OpenDebugAD7 /usr/bin/OpenDebugAD7
chmod +x /usr/bin/OpenDebugAD7
nvim --headless "+TSUninstall python" -c "q"

# install claude code
npm install -g @anthropic-ai/claude-code

claude plugin marketplace add Yeachan-Heo/oh-my-claude-sisyphus
claude plugin install oh-my-claude-sisyphus

# claude plugin marketplace add anthropics/claude-plugins-official
# claude plugin install context7@claude-plugins-official
# claude plugin install frontend-design@claude-plugins-official
# # claude plugin install serena@claude-plugins-official
# claude plugin install feature-dev@claude-plugins-official
# claude plugin install code-review@claude-plugins-official
# claude plugin install security-guidance@claude-plugins-official
# claude plugin install pr-review-toolkit@claude-plugins-officia
# claude plugin install hookify@claude-plugins-official
# claude plugin install ralph-wiggum@claude-plugins-official
# claude plugin install greptile@claude-plugins-official
# claude plugin install playwright@claude-plugins-official
#
# claude plugin install typescript-lsp@claude-plugins-official
# claude plugin install pyright-lsp@claude-plugins-official
# claude plugin install gopls-lsp@claude-plugins-official
# claude plugin install rust-analyzer-lsp@claude-plugins-official
# claude plugin install csharp-lsp@claude-plugins-official
# claude plugin install php-lsp@claude-plugins-official
# claude plugin install swift-lsp@claude-plugins-official
# claude plugin install jdtls-lsp@claude-plugins-official
# claude plugin install clangd-lsp@claude-plugins-official
# claude plugin install lua-lsp@claude-plugins-official
# claude mcp add sequential-thinking npx -- -y @modelcontextprotocol/server-sequential-thinking
# claude mcp add apidog -- npx -y apidog-mcp-server@latest --oas=https://petstore.swagger.io/v2/swagger.json
# claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
# claude mcp add server-filesystem-- npx -- -y @modelcontextprotocol/server-filesystem

# ui
## statusline
npm install -g @cometix/ccline
mkdir -p ~/.claude
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$CLAUDE_SETTINGS" ]; then
    jq '.statusLine = {"type": "command", "command": "~/.claude/ccline/ccline", "padding": 0}' "$CLAUDE_SETTINGS" >"${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
else
    echo '{"statusLine": {"type": "command", "command": "~/.claude/ccline/ccline", "padding": 0}}' >"$CLAUDE_SETTINGS"
fi

# install codex
npm i -g @openai/codex

# install opencode
curl -fsSL https://opencode.ai/install | bash
curl -fsSL https://bun.com/install | bash
bunx oh-my-opencode install

# link opencode configuration
echo
echo '** link opencode configuration.'
mkdir -p $HOME/.config/opencode
ln -sf $DOT_DIR/opencode/opencode.jsonc $HOME/.config/opencode/opencode.jsonc
### bunx oh-my-opencode install --no-tui --claude=<yes|no|max20> --chatgpt=<yes|no> --gemini=<yes|no>

# chromium for playwright
npx playwright install chromium

#==================================================
# set zsh to the default shell
echo
echo '** set ZSH as default shell.'
locale-gen en_US.UTF-8
echo "exec zsh" >>$HOME/.bash_profile
exec zsh
