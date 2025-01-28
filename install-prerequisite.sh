###### APT ##### 
apt-get install -y software-properties-common curl
add-apt-repository -y ppa:neovim-ppa/stable 
apt-get update;
curl -s https://deb.nodesource.com/setup_20.x | bash
apt-get install -y sudo python3-opencv aria2 gcc cmake libgl1 libglib2.0-0 g++ nodejs
apt-get install -y unzip zip zsh wget neovim tmux curl git htop libgl1 libglib2.0-0 rsync

###### PIP ##### 
# vim plugin Prerequisites
## jedi-vim
pip install pynvim
##  ale
pip install isort
# gpustat
pip install gpustat
