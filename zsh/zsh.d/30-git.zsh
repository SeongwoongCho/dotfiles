#!/bin/zsh
# Git aliases and functions

# Config shortcuts
alias guname="git config --file ~/.gitconfig.secret user.name"
alias guemail="git config --file ~/.gitconfig.secret user.email"

# Common operations
alias ga='git add'
alias gst='git status'
alias gd='git diff'
alias gcm='git commit -m'
alias gcmd='git commit -m "."'
alias gcl='git clone'
alias gps='git push'
alias gpl='git pull'

# Clone from GitHub
function gclone() {
    local user="$1"
    local repo="$2"
    if [ -z "$user" ] || [ -z "$repo" ]; then
        echo 'Clone from GitHub'
        echo 'Usage: gclone [user] [repository]'
        return 1
    fi
    git clone "git@github.com:$user/$repo.git"
}

# Add remote origin
function gra() {
    local user="$1"
    local repo="$2"
    if [ -z "$user" ] || [ -z "$repo" ]; then
        echo 'Add GitHub remote origin'
        echo 'Usage: gra [USERNAME] [REPONAME]'
        return 1
    fi
    git remote add origin "git@github.com:$user/$repo.git"
}
