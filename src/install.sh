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
mkdir -p $HOME/.config/nvim && ln -sf $DOT_DIR/init.lua $HOME/.config/nvim/init.lua && ln -sf $DOT_DIR/lua $HOME/.config/nvim/lua
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
pip install pylatexenc

bash; # cargo
cargo install --locked tree-sitter-cli # to install latex parser
nvim --headless "+TSUpdateSync lua c cpp markdown markdown_inline latex html bash diff luadoc query vim vimdoc" -c "q"
nvim --headless "+TSUninstall python" -c "q"

# coc setup
## :call coc#util#install()
cd ~/.local/share/nvim/lazy/coc.nvim/
npm install
cd $DOT_DIR
nvim --headless "+CocInstall -sync coc-clangd" +qa

# vscode symlink
ln -sf $DOT_DIR/cpptools-linux-x64/extension/debugAdapters/bin/OpenDebugAD7 /usr/bin/OpenDebugAD7
chmod +x /usr/bin/OpenDebugAD7

#==================================================#
# set zsh to the default shell
echo; echo '** set ZSH as default shell.'
locale-gen en_US.UTF-8
echo "exec zsh" >> $HOME/.bash_profile
exec zsh
