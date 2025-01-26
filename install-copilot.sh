#! /bin/bash

# nodejs 20.x version
apt-get install -y software-properties-common curl
curl -s https://deb.nodesource.com/setup_20.x | bash

# copilot
git clone https://github.com/github/copilot.vim.git $HOME/.vim/pack/github/start/copilot.vim
