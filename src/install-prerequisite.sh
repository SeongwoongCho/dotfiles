#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n>> %s\n' "$1"; }
apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log "update apt sources and install base tools"
apt-get update
apt-get install -y software-properties-common curl
add-apt-repository -y ppa:neovim-ppa/unstable
apt-get update
curl -s https://deb.nodesource.com/setup_20.x | bash

log "install rust and tree-sitter"
curl https://sh.rustup.rs -sSf | sh -s -- -y
export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v tree-sitter >/dev/null 2>&1; then
    cargo install --locked tree-sitter-cli
fi

log "install apt packages"
apt_install sudo python3-opencv aria2 gcc cmake libgl1 libglib2.0-0 g++ ccache nodejs
apt_install  unzip zip zsh ssh wget curl git htop rsync fzf libgl1 libglib2.0-0
apt_install  tmux libevent-dev ncurses-dev bison locales chafa pkg-config build-essential libreadline-dev ripgrep fd-find
apt_install  clang-format clang clangd clangd-12 libomp-dev gdb
apt_install  python3-venv

log "install shfmt"
curl -sS https://webi.sh/shfmt | sh
if [ -f ~/.config/envman/PATH.env ]; then
    # shellcheck source=/dev/null
    source ~/.config/envman/PATH.env
fi

log "install git-delta"
cargo install git-delta

log "install vscode c++ extension"
wget https://github.com/microsoft/vscode-cpptools/releases/download/v1.24.1/cpptools-linux-x64.vsix
unzip cpptools-linux-x64.vsix -d cpptools-linux-x64/
rm -r cpptools-linux-x64.vsix

log "build neovim from source"
apt_install  ninja-build gettext cmake unzip curl build-essential
git clone https://github.com/neovim/neovim -b v0.11.3 ~/.neovim
pushd ~/.neovim >/dev/null
CC=gcc CXX=g++ make CMAKE_BUILD_TYPE=RelWithDebInfo
make install
popd >/dev/null

log "install lua 5.1.5"
LUA_TMP=$(mktemp -d)
pushd "$LUA_TMP" >/dev/null
wget http://www.lua.org/ftp/lua-5.1.5.tar.gz
tar zxf lua-5.1.5.tar.gz
cd lua-5.1.5
make linux test
make install
popd >/dev/null
rm -rf "$LUA_TMP"

log "install luarocks"
LUAROCKS_TMP=$(mktemp -d)
pushd "$LUAROCKS_TMP" >/dev/null
wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz
tar zxpf luarocks-3.11.1.tar.gz
cd luarocks-3.11.1
./configure && make && make install
luarocks install luasocket
popd >/dev/null
rm -rf "$LUAROCKS_TMP"

log "install kitty backend and magick"
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
luarocks --lua-version=5.1 install magick
apt_install imagemagick libmagickwand-dev

log "install python tooling with uv"
pip install uv
uv self update
uv pip install --system pynvim
uv pip install --system isort
uv pip install --system gpustat
uv pip install --system pre-commit
uv pip install --system black
uv pip install --system jedi_language_server
uv pip install --system python-lsp-server
uv pip install --system thefuck

log "add mobilint apt source and tools"
apt-get update
apt_install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://dl.mobilint.com/apt/gpg.pub -o /etc/apt/keyrings/mblt.asc
chmod a+r /etc/apt/keyrings/mblt.asc
printf "%s\n" \
    "deb [signed-by=/etc/apt/keyrings/mblt.asc] https://dl.mobilint.com/apt stable multiverse" \
    "deb [signed-by=/etc/apt/keyrings/mblt.asc] https://dl.mobilint.com/apt $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") multiverse" |
    tee /etc/apt/sources.list.d/mobilint.list >/dev/null
apt-get update
apt_install mobilint-cli
uv pip install --system maccel

cd "$ROOT_DIR"
