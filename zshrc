## set default paths

export MYDOTFILES=$HOME/.dotfiles
export PATH=$HOME/bin:/usr/local/bin:/usr/local/cuda/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$MYDOTFILES/tmux:$PATH
export PATH=$HOME/.mbltmon/build/src/mbltmon:$PATH
export SHELL=$(which zsh)
export ZSH=$HOME/.oh-my-zsh # oh-my-zsh
export LANGUAGE=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# export LANG
# export FZF_DEFAULT_COMMAND='fd - type f'
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'

#==================================================#
# terminal settings
export TERM='xterm-256color' # terminal color


#==================================================#
### zsh settings
export LS_COLORS=$(cat $MYDOTFILES/assets/LS_COLORS)

# OH-MY-ZSH
# themes: https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="mrtazz_custom"   # set zsh theme
DISABLE_AUTO_UPDATE="true"  # no automatically update oh-my-zsh
HIST_STAMPS="mm/dd/yyyy"    # history with date stamps


source $ZSH/oh-my-zsh.sh
setopt nosharehistory # do not share command line history across tmux windows/panes

# https://stackoverflow.com/questions/20512957/zsh-new-line-prompt-after-each-command
function precmd() {
    # Print a newline before the prompt, unless it's the
    # first prompt in the process.
    if [ -z "$NEW_LINE_BEFORE_PROMPT" ]; then
        NEW_LINE_BEFORE_PROMPT=1
    elif [ "$NEW_LINE_BEFORE_PROMPT" -eq 1 ]; then
        echo ""
    fi
}

#==================================================#
### zsh plugins
source ~/.zplug/init.zsh
zplug "djui/alias-tips"
zplug "zsh-users/zsh-syntax-highlighting"
zplug "zsh-users/zsh-autosuggestions"
zplug "junegunn/fzf"
zplug "sharkdp/fd"

# Then, source plugins and add commands to $PATH
zplug check || zplug install
zplug load


#==================================================#
### misc

# preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# ssh
export SSH_KEY_PATH="~/.ssh/id_rsa"

# personal aliases
for alias_file in "$HOME/.aliases"/*
do
    source $alias_file
done

# fzf
function fuzzyvim()
{
    vim $(fzf)
}
zle -N fuzzyvim 

# remove duplicates in PATH
export PATH="$(echo -n $PATH | awk -v RS=: -v ORS=: '!arr[$0]++')"

bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word

# fash compilation
export CC='ccache gcc'
export CXX='ccache g++'

eval $(thefuck --alias)
