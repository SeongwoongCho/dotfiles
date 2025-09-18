###### APT ##### 
apt-get update;
apt-get install -y software-properties-common curl
add-apt-repository -y ppa:neovim-ppa/unstable 
apt-get update;
curl -s https://deb.nodesource.com/setup_20.x | bash
# install cargo
curl https://sh.rustup.rs -sSf | sh -s -- -y
export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v tree-sitter >/dev/null 2>&1; then
    cargo install --locked tree-sitter-cli # for latex parser
fi

DEBIAN_FRONTEND=noninteractive apt-get install -y sudo python3-opencv aria2 gcc cmake libgl1 libglib2.0-0 g++ ccache nodejs 
DEBIAN_FRONTEND=noninteractive apt-get install -y unzip zip zsh wget curl git htop libgl1 libglib2.0-0 rsync fzf
DEBIAN_FRONTEND=noninteractive apt-get install -y tmux libevent-dev ncurses-dev bison locales chafa pkg-config build-essential libreadline-dev ripgrep fd-find
DEBIAN_FRONTEND=noninteractive apt-get install -y clang-format clang clangd clangd-12 libomp-14-dev gdb
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv
cargo install git-delta

# vscode cpp extension: https://github.com/microsoft/vscode-cpptools/releases
wget https://github.com/microsoft/vscode-cpptools/releases/download/v1.24.1/cpptools-linux-x64.vsix 
unzip cpptools-linux-x64.vsix -d cpptools-linux-x64/
rm -r cpptools-linux-x64.vsix

# neovim #
DEBIAN_FRONTEND=noninteractive apt-get install -y ninja-build gettext cmake unzip curl build-essential
git clone https://github.com/neovim/neovim -b v0.11.3 ~/.neovim
cd ~/.neovim && CC=gcc CXX=g++ make CMAKE_BUILD_TYPE=RelWithDebInfo
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
DEBIAN_FRONTEND=noninteractive apt-get install -y imagemagick libmagickwand-dev


###### PIP ##### 
pip install uv
uv self update

# vim plugin Prerequisites
## jedi-vim
uv pip install pynvim
##  ale
uv pip install isort
# gpustat
uv pip install gpustat==1.0.0
# precommit & formmater
uv pip install pre-commit
uv pip install black
