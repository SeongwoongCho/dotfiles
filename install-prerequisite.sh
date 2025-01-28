###### APT ##### 
apt-get install -y software-properties-common curl
add-apt-repository -y ppa:neovim-ppa/unstable 
apt-get update;
curl -s https://deb.nodesource.com/setup_20.x | bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
apt-get install -y sudo python3-opencv aria2 gcc cmake libgl1 libglib2.0-0 g++ nodejs
apt-get install -y unzip zip zsh wget neovim tmux curl git htop libgl1 libglib2.0-0 rsync
apt-get install -y build-essential libreadline-dev

###### LUA #####
echo **** Installing Lua ****
mkdir lua_build && cd lua_build
wget http://www.lua.org/ftp/lua-5.4.4.tar.gz
tar zxf lua-5.4.4.tar.gz
cd lua-5.4.4
make linux test
make install
cd ../.. && rm -r lua_build

###### PIP ##### 
# vim plugin Prerequisites
## jedi-vim
pip install pynvim
##  ale
pip install isort
# gpustat
pip install gpustat
