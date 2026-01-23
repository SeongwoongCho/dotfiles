#!/bin/zsh
# Utility functions

# backup existing dotfiles (buo: back-up-original)
function buo() {
    backup_dir="$HOME/dotfiles_backup"
    for name in "$@"; do
        path="$HOME/$name"
        if [ -f "$path" ] || [ -h "$path" ] || [ -d "$path" ]; then
            mkdir -p "$backup_dir"
            new_path="$backup_dir/$name"
            printf "Found '$path'. Backing up to '$new_path'\n"
            mv "$path" "$new_path"
        fi
    done
}

# colorprint: display file with ANSI colors
function colorprint() {
    cat "$1" | sed -E 's/\[([0-9;]+)m/\x1b[\1m/g'
}

# rsync with custom port
function myrsync() {
    local port="$1"
    local remainder="$2"
    local cmd="rsync -avzhe 'ssh -p ${port}' ${remainder}"
    echo "$cmd"
    eval "$cmd"
}

# count files matching pattern
function howmany() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo 'Count files with PATTERN in LOCATION'
        echo 'Usage: howmany LOCATION "PATTERN"'
        echo 'Example: howmany /path/to/images/ "*.jpg"'
        return 1
    fi
    set -o noglob
    local dirname="$1"
    local pattern="$2"
    find "${dirname}" -name "${pattern}" -printf '.' | wc -m
    set -o glob
}

# clean python cache files
function pyclean() {
    find . | grep -E '(/__pycache__$|\.pyc$|\.pyo$|\.ipynb_checkpoints$)' | xargs rm -rf
}

# fzf + vim integration
function fuzzyvim() {
    vim "$(fzf)"
}

# GPU device selection
function usegpu() {
    if [ -n "$1" ]; then
        export CUDA_VISIBLE_DEVICES="$1"
    else
        export CUDA_VISIBLE_DEVICES=''
    fi
}

# HPU device selection (Habana)
function usehpu() {
    if [ -n "$1" ]; then
        export HABANA_VISIBLE_MODULES="$1"
    else
        export HABANA_VISIBLE_MODULES=''
    fi
}
