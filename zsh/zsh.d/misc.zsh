#! /bin/bash

# backup existing dotfiles.
# (buo : back-up-original)
function buo() {
    backup_dir="$HOME/dotfiles_backup"
    for name in "$@"; do
        path="$HOME/$name"
        if [ -f $path ] || [ -h $path ] || [ -d $path ]; then
            mkdir -p $backup_dir
            new_path="$backup_dir/$name"
            printf "Found '$path'. Backing up to '$new_path\n"
            mv $path $new_path
        fi
    done
}

function usegpu() {
    if [ ! -z "$1" ]; then
        export CUDA_VISIBLE_DEVICES=$1
    else
        export CUDA_VISIBLE_DEVICES=''
    fi
}
function colorprint() {
    cmd="cat $1 | sed -E 's/\[([0-9;]+)m/\x1b[\1m/g'"
    eval $cmd
}

function myrsync() {
    port=$1
    remainder=$2
    cmd="rsync -avzhe 'ssh -p ${port}' ${remainder}"
    echo $cmd
    eval $cmd
}

function howmany() {
    function help() {
        echo 'Count the number of files with PATTERN in a specific location LOCATION'
        echo 'Usage: howmany LOCATION "PATTERN"'
        echo 'Example: howmany /path/to/your/images/ "*.jpg"'
    }
    if [ -z "$1" ]; then
        help
    elif [ -z "$2" ]; then
        help
    else
        set -o noglob
        dirname=$1
        pattern=$2
        cmd="find ${dirname} -name ${pattern} -printf '.' | wc -m"
        echo $cmd
        eval $cmd
        set -o glob
    fi
}

function pyclean() {
    cmd="find . | grep -E '(/__pycache__$|\.pyc$|\.pyo$|\.ipynb_checkpoints$)' | xargs rm -rf"
    echo $cmd
    eval $cmd
}

# tmux
alias tmux='tmux -u'

# visdom
alias vim='nvim'
alias vis='python -m visdom.server'
alias vimconflicts='vim $(git diff --name-only --diff-filter=U)'

# jupyter notebook
alias jn='jupyter notebook'
alias jna='jupyter notebook --ip 0.0.0.0'
alias jl='jupyter lab'
alias jla='jupyter lab --ip 0.0.0.0 --allow-root'

# gpu
alias gpu="watch --color -n.5 gpustat --color"
alias gpusmi="watch -n.5 nvidia-smi"
alias npu="watch --color -n.5 npustat --color"
alias ug='usegpu'

# cmake auto
alias cmakeauto='cmake .. -DPRODUCT=aries2-v4 -DDRIVER_TYPE=aries2 -DVENDOR=mobilint'
alias cmakeauto2='cmake .. -DPRODUCT=aries2-v4 -DDRIVER_TYPE=aries2 -DVENDOR=mobilint -DINCLUDE_JSON=True -DCMAKE_EXPORT_COMPILE_COMMANDS=1'
alias cmakeauto_r='cmake .. -DPRODUCT=regulus-v4 -DDRIVER_TYPE=regulus -DVENDOR=mobilint'
alias cmakeauto2_r='cmake .. -DPRODUCT=regulus-v4 -DDRIVER_TYPE=regulus -DVENDOR=mobilint -DINCLUDE_JSON=True -DCMAKE_EXPORT_COMPILE_COMMANDS=1'

# hpu
alias hpusmi="watch -n.5 hl-smi"
function usehpu() {
    if [ ! -z "$1" ]; then
        export HABANA_VISIBLE_MODULES=$1
    else
        export HABANA_VISIBLE_MODULES=''
    fi
}
alias uh='usehpu'

# misc
alias du='du -hd 1'
alias cudav='nvcc --version'
alias cudnnv='cat /usr/local/cuda/include/cudnn.h | grep CUDNN_MAJOR -A 2'
alias jnlist='jupyter notebook list'
alias tblist='ps -ef | grep "tensorboard"'
alias pylist='ps -ef | grep "python"'

# colorprint 
alias cpr='colorprint'

# ls, df
alias ls='eza'
alias df='duf'
alias cd='z'
alias bat='batcat'
alias claude='SHELL=/bin/bash claude'

# opencode
function askai() {
    opencode run "$*" --model opencode/big-pickle
}
