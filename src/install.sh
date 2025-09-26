#! /bin/bash

#=================================================#
# argument parser
while getopts 'i:' flag; do
  case "${flag}" in
    i) install_avante='true' ;;
    esac
done

#=================================================#
# handling avante
if [ "$install_avante" = "true" ];
then
    mv $DOT_DIR/lua/plugins/avante.lua $DOT_DIR/lua/plugins/avante.lua.old
else
    mv $DOT_DIR/lua/plugins/avante.lua.old $DOT_DIR/lua/plugins/avante.lua
fi

#==================================================#
DOT_DIR=$PWD
echo; echo '** DOT_DIR: ' $DOT_DIR

#==================================================#
echo; echo '** download prerequisite libraries.'
bash $DOT_DIR/src/install-prerequisite.sh


#==================================================#
echo; echo '** link custom configurations.'
source "$PWD/aliases/misc"
ln -sf $DOT_DIR/assets/Xmodmap $HOME/.Xmodmap

# Clean and link nvim configuration
rm -rf $HOME/.config/nvim
mkdir -p $HOME/.config
ln -sfn $DOT_DIR $HOME/.config/nvim

ln -sf $DOT_DIR/tmux.conf $HOME/.tmux.conf
ln -sf $DOT_DIR/aliases $HOME/.aliases
ln -sf $DOT_DIR/gitconfig $HOME/.gitconfig
ln -sf $DOT_DIR/zshrc $HOME/.zshrc
ln -sf $DOT_DIR/coc-settings.json $HOME/.config/nvim/coc-settings.json

# #==================================================#
echo; echo '** download oh-my-zsh.'
bash $DOT_DIR/src/install-omz.sh; 
ln -sf $DOT_DIR/assets/mrtazz_custom.zsh-theme $HOME/.oh-my-zsh/themes/


#==================================================#
# download useful plugins
echo; echo '** download zsh plugin manager, zplug.'
git clone https://github.com/zplug/zplug $HOME/.zplug


#==================================================#
# download neovim plugins from lazy.nvim
nvim --headless "+Lazy! install" +qa
# nvim --headless "+Lazy! update" +qa
uv pip install --system pylatexenc

nvim --headless "+TSUpdateSync lua c cpp markdown markdown_inline latex html bash diff luadoc query vim vimdoc" -c "q"

# coc setup
## :call coc#util#install()
# cd ~/.local/share/nvim/lazy/coc.nvim/
# npm install
# cd $DOT_DIR
# nvim --headless "+CocInstall -sync coc-clangd" +qa

# mason setup
nvim --headless "MasonInstall clangd" +qa



# vscode symlink
ln -sf $DOT_DIR/cpptools-linux-x64/extension/debugAdapters/bin/OpenDebugAD7 /usr/bin/OpenDebugAD7
chmod +x /usr/bin/OpenDebugAD7
nvim --headless "+TSUninstall python" -c "q"

# codeium
# todo: we have to explicitly run the following code. Fix this to automate. 
chown -R root:root ~/.cache/nvim/codeium
chmod -R 755 ~/.cache/nvim/codeium
# register codeium key automatically
echo '{"api_key": "sk-ws-01-dnDT0n46kqpivATCL6dOA65i_UTyF0y5ryAgBHoFGWgYPzDYFEzj14nutfqo8ACRwq_7p0V772sQ9VcosYnwWCqnjvouQQ"}' >> ~/.cache/nvim/codeium/config.json

#==================================================#
# set zsh to the default shell
echo; echo '** set ZSH as default shell.'
locale-gen en_US.UTF-8
echo "exec zsh" >> $HOME/.bash_profile
exec zsh
