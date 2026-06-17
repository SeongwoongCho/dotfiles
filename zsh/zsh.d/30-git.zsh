#!/bin/zsh
# Git aliases and functions

# Config shortcuts
alias guname="git config --file ~/.gitconfig.secret user.name"
alias guemail="git config --file ~/.gitconfig.secret user.email"

# Common operations
alias ga='git add'
alias gst='git status'
alias gcm='git commit -m'
alias gcmd='git commit -m "."'
alias gcl='git clone'
alias gps='git push'
alias gpl='git pull'

# gd: zoom-aware git diff — re-renders on tmux pane resize with position restore
function gd() {
    if [[ -z "$TMUX" ]]; then
        git diff "$@"
        return
    fi

    setopt localoptions no_monitor no_notify

    local raw=$(mktemp)
    git diff --no-color "$@" > "$raw"
    if [[ ! -s "$raw" ]]; then
        rm -f "$raw"
        return 0
    fi

    local search=""
    while true; do
        local w1=$(tmux display-message -p '#{pane_width}')

        (
            while true; do
                sleep 0.2
                local w=$(tmux display-message -p '#{pane_width}' 2>/dev/null)
                if [[ "$w" != "$w1" ]]; then
                    [[ ! -f /tmp/.tmux_pane_capture ]] && \
                        tmux capture-pane -p > /tmp/.tmux_pane_capture 2>/dev/null
                    sleep 0.05
                    tmux send-keys -t "$TMUX_PANE" q 2>/dev/null
                    break
                fi
            done
        ) &
        local monitor_pid=$!

        if [[ -n "$search" ]]; then
            local target_line=$(
                COLUMNS="$w1" delta --width="$w1" < "$raw" \
                | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g' \
                | grep -nm1 "$search" | cut -d: -f1
            )
            if [[ -n "$target_line" ]]; then
                COLUMNS="$w1" delta --width="$w1" < "$raw" | less -R "+${target_line}g"
            else
                COLUMNS="$w1" delta --width="$w1" < "$raw" | less -R
            fi
        else
            COLUMNS="$w1" delta --width="$w1" < "$raw" | less -R
        fi

        kill $monitor_pid 2>/dev/null
        wait $monitor_pid 2>/dev/null

        local w2=$(tmux display-message -p '#{pane_width}')
        [[ "$w1" == "$w2" ]] && break

        search=""
        if [[ -f /tmp/.tmux_pane_capture ]]; then
            search=$(_gd_extract_anchor /tmp/.tmux_pane_capture)
            rm -f /tmp/.tmux_pane_capture
        fi
    done

    rm -f "$raw"
}

_gd_extract_anchor() {
    local f="$1" total mid anchor
    total=$(wc -l < "$f")
    mid=$((total / 2))

    anchor=$(
        head -n "$((mid + 3))" "$f" \
        | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\][^\x07]*\x07//g' \
        | sed 's/│//g' \
        | grep -oE '[a-zA-Z0-9_][a-zA-Z0-9_./-]*/[a-zA-Z0-9_./-]+' \
        | tail -1
    )
    [[ -n "$anchor" ]] && { echo "$anchor"; return; }

    anchor=$(
        sed -n "${mid}p" "$f" \
        | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
        | sed 's/│/ /g; s/^[[:space:]]*[0-9]*[[:space:]]*//' \
        | xargs | cut -c1-40
    )
    [[ -n "$anchor" && ${#anchor} -ge 4 ]] && echo "$anchor"
}

# Setup git user name and email
# Usage: gitsetup --name "John Doe" --email "john@example.com"
function gitsetup() {
    local name="" email=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)  name="$2"; shift 2 ;;
            --email) email="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; echo "Usage: gitsetup --name <name> --email <email>"; return 1 ;;
        esac
    done
    if [[ -z "$name" || -z "$email" ]]; then
        echo "Usage: gitsetup --name <name> --email <email>"
        return 1
    fi
    git config --file ~/.gitconfig.secret user.name "$name"
    git config --file ~/.gitconfig.secret user.email "$email"
    echo "Git user configured:"
    echo "  name:  $name"
    echo "  email: $email"
}

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
