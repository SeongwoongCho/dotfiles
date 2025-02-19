###### APT ##### 
apt-get install -y software-properties-common curl
add-apt-repository -y ppa:neovim-ppa/unstable 
apt-get update;
curl -s https://deb.nodesource.com/setup_20.x | bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
apt-get install -y sudo python3-opencv aria2 gcc cmake libgl1 libglib2.0-0 g++ nodejs
apt-get install -y unzip zip zsh wget curl git htop libgl1 libglib2.0-0 rsync fzf
apt-get install -y tmux libevent-dev ncurses-dev bison locales chafa pkg-config build-essential libreadline-dev ripgrep fd-find
apt-get install -y clangd clangd-12


# neovim #
apt-get install ninja-build gettext cmake unzip curl build-essential
git clone https://github.com/neovim/neovim -b v0.10.3 ~/.neovim
cd ~/.neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo
make install
cd ~/.dotfiles

# # ###### TMUX ##### 
# echo **** Installing Latest tmux from the source **** 
# apt-get remove -y tmux
#
# ## tmux
# git clone https://github.com/tmux/tmux.git ~/.tmux
# cd .tmux
# sh autogen.sh
# ./configure && make
# cd ~/.dotfiles

###### LUA #####
echo **** Installing Lua ****
mkdir lua_build && cd lua_build
wget http://www.lua.org/ftp/lua-5.1.5.tar.gz
tar zxf lua-5.1.5.tar.gz
cd lua-5.1.5
make linux test
make install
cd ../.. && rm -r lua_build

echo **** Installing Luarocks **** 
mkdir lua_build && cd lua_build
wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz
tar zxpf luarocks-3.11.1.tar.gz
cd luarocks-3.11.1
./configure && make && make install
luarocks install luasocket
cd ../.. && rm -r lua_build


###### Installing Kitty backend & magick for image visualization (image.nvim) in vim ##### 
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
luarocks --lua-version=5.1 install magick
apt-get install -y imagemagick libmagickwand-dev


###### PIP ##### 
# vim plugin Prerequisites
## jedi-vim
pip install pynvim
##  ale
pip install isort
# gpustat
pip install gpustat
