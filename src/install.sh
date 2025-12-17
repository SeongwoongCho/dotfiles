#! /bin/bash

#==================================================#
DOT_DIR=$PWD
echo
echo '** DOT_DIR: ' $DOT_DIR

#==================================================#
echo
echo '** download prerequisite libraries.'
bash $DOT_DIR/etc/install-prerequisite.sh

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
bash $DOT_DIR/etc/install-omz.sh
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
# nvim --headless "+Lazy! update" +qa
uv pip install --system pylatexenc

nvim --headless "+TSUpdateSync lua c cpp markdown markdown_inline latex html bash diff luadoc query vim vimdoc" -c "q"

# mason setup
nvim --headless "MasonInstall clangd" +qa

# vscode symlink
ln -sf $DOT_DIR/cpptools-linux-x64/extension/debugAdapters/bin/OpenDebugAD7 /usr/bin/OpenDebugAD7
chmod +x /usr/bin/OpenDebugAD7
nvim --headless "+TSUninstall python" -c "q"

# install claude code
npm install -g @anthropic-ai/claude-code
claude mcp add sequential-thinking npx -- -y @modelcontextprotocol/server-sequential-thinking
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add apidog -- npx -y apidog-mcp-server@latest --oas=https://petstore.swagger.io/v2/swagger.json
claude mcp add memory -- npx -y @modelcontextprotocol/server-memory
claude mcp add server-filesystem-- npx -- -y @modelcontextprotocol/server-filesystem

# install codex
npm i -g @openai/codex

#==================================================#
# set zsh to the default shell
echo
echo '** set ZSH as default shell.'
locale-gen en_US.UTF-8
echo "exec zsh" >>$HOME/.bash_profile
exec zsh
