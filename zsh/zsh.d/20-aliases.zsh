#!/bin/zsh
# Common aliases

# Editor
alias vim='nvim'
alias vimconflicts='vim $(git diff --name-only --diff-filter=U)'

# Terminal multiplexer
alias tmux='tmux -u'

# Jupyter
alias jn='jupyter notebook'
alias jna='jupyter notebook --ip 0.0.0.0'
alias jl='jupyter lab'
alias jla='jupyter lab --ip 0.0.0.0 --allow-root'

# Modern CLI replacements
alias ls='eza'
alias df='duf'
alias bat='batcat'
if [[ $- == *i* ]]; then
    alias cd='z'
fi

# Utilities
alias du='du -hd 1'
alias cpr='colorprint'

# Process listing
alias jnlist='jupyter notebook list'
alias tblist='ps -ef | grep "tensorboard"'
alias pylist='ps -ef | grep "python"'

# Claude Code
alias claude='IS_SANDBOX=1 claude --dangerously-skip-permissions'

# GPU/NPU/HPU monitoring
alias ug='usegpu'
alias gpu="watch --color -n.5 gpustat --color"
alias gpusmi="watch -n.5 nvidia-smi"
alias npu="watch --color -n.5 npustat --color"
alias uh='usehpu'
alias hpusmi="watch -n.5 hl-smi"

# CUDA version info
alias cudav='nvcc --version'
alias cudnnv='cat /usr/local/cuda/include/cudnn.h | grep CUDNN_MAJOR -A 2'

# CMake presets (Mobilint)
alias cmakeauto='cmake .. -DPRODUCT=aries2-v4 -DDRIVER_TYPE=aries2 -DVENDOR=mobilint'
alias cmakeauto2='cmake .. -DPRODUCT=aries2-v4 -DDRIVER_TYPE=aries2 -DVENDOR=mobilint -DINCLUDE_JSON=True -DCMAKE_EXPORT_COMPILE_COMMANDS=1'
alias cmakeauto_r='cmake .. -DPRODUCT=regulus-v4 -DDRIVER_TYPE=regulus -DVENDOR=mobilint'
alias cmakeauto2_r='cmake .. -DPRODUCT=regulus-v4 -DDRIVER_TYPE=regulus -DVENDOR=mobilint -DINCLUDE_JSON=True -DCMAKE_EXPORT_COMPILE_COMMANDS=1'
