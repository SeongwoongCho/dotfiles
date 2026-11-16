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

# Claude Code (auto-update OMC before launch)
# alias claude='omc update && IS_SANDBOX=1 command claude --dangerously-skip-permissions --model "claude-fable-5-1[1m]" --effort low'
alias claude='omc update && IS_SANDBOX=1 command claude --dangerously-skip-permissions --model "claude-fable-5[1m]" --effort high'
# alias claude='omc update && IS_SANDBOX=1 command claude --dangerously-skip-permissions --model "claude-opus-4-6[1m]" --effort max'
# Codex launcher lives in 10-functions.zsh (version-checked auto-update)

# scheduler-cli (try updating first; run even if the update fails). A function
# rather than an alias, so that `x | scheduler-cli ...` still feeds the real
# command and `cond && scheduler-cli ...` still honours cond. The update is
# silent when already current, speaks on stderr otherwise (so piping
# `scheduler-cli ps --json` stays clean), and is given at most 10 seconds.
scheduler-cli() {
    timeout 10 scheduler-cli update </dev/null 2>&1 \
        | grep -v "is the latest release" >&2
    command scheduler-cli "$@"
}

# GPU/NPU/HPU monitoring
alias ug='usegpu'
alias gpu="watch --color -n.5 gpustat --color"
alias gpusmi="watch -n.5 nvidia-smi"
# npustat's own watch mode rather than `watch`: it redraws at once when the
# pane is resized, instead of at the next run.
alias npu="npustat -i .5"
alias uh='usehpu'
alias hpusmi="watch -n.5 hl-smi"

# CUDA version info
alias cudav='nvcc --version'
alias cudnnv='cat /usr/local/cuda/include/cudnn.h | grep CUDNN_MAJOR -A 2'

# CMake presets (Mobilint)
alias cmakeauto='cmake .. -G Ninja -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=mold" -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=mold -DCMAKE_EXPORT_COMPILE_COMMANDS=ON" -DENABLE_NDE_API=ON'

# Dotfiles management
alias dotup='bash $MYDOTFILES/src/update.sh'
alias dotup-full='bash $MYDOTFILES/src/update.sh --full'
alias dotsecret='bash $MYDOTFILES/src/install-secrets.sh --save'
alias dotcd='cd $MYDOTFILES'

