#! /bin/bash

#==================================================#
# argument parser
# usage : https://stackoverflow.com/questions/7069682/how-to-get-arguments-with-flags-in-bash
while getopts 'fu:' flag; do
  case "${flag}" in
    f) forced='true' ;;
    u) update="${OPTARG}" ;;
    esac
done

#==================================================#
DOT_DIR=$PWD
ZSH=$HOME/.oh-my-zsh
ZSH_CUSTOM=$ZSH/custom
ZPLUG_HOME=$HOME/.zplug

#==================================================#
source "$PWD/aliases/misc"
if [ "$forced" != "true" ]; then
    buo .Xmodmap .vim .vimrc ~/.config/.init.vim .tmux.conf .aliases .gitconfig .gitconfig.secret .zshrc .oh-my-zsh .fzf
fi
ln -sf $DOT_DIR/Xmodmap $HOME/.Xmodmap 
mkdir -p $HOME/.config/nvim && ln -sf $DOT_DIR/init.vim $HOME/.config/nvim/init.vim
ln -sf $DOT_DIR/tmux.conf $HOME/.tmux.conf
ln -sf $DOT_DIR/aliases $HOME/.aliases
ln -sf $DOT_DIR/gitconfig $HOME/.gitconfig
ln -sf $DOT_DIR/zshrc $HOME/.zshrc


#==================================================#
echo; echo '** download prerequisite libraries.'
bash install-prerequisite.sh


# #==================================================#
echo; echo '** download oh-my-zsh.'
bash $DOT_DIR/install-omz.sh; 
ln -sf $DOT_DIR/themes/mrtazz_custom.zsh-theme $HOME/.oh-my-zsh/themes/


#==================================================#
# download useful plugins
echo; echo '** download zsh plugsin.'
git clone https://github.com/zplug/zplug $ZPLUG_HOME

# neovim 
echo; echo '** download neovim plugins.'
## Vim-Plug for neovim
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
## install plugins
nvim --headless +'PlugInstall --sync' +qa
nvim +'UpdateRemotePlugins --sync' +qa


#==================================================#
# set zsh to the default shell
echo; echo '** set ZSH as default shell.'
echo "exec zsh" >> $HOME/.bash_profile
exec zsh
