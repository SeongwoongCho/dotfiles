# prompt configuration tips:
# http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html

# color options
# foreground font color: %{$FG[FG_CODE]%} (see spectrum_ls for details about FG_CODE)
# background color: %{$BG[BG_CODE]%} (see spectrum_bls for details about BG_CODE)
# reset: %{$reset_color%}

function cuda_prompt_info(){
    if [[ ! -z "$CUDA_VISIBLE_DEVICES" ]]; then
        echo "| %{$FG[141]%}cuda:${CUDA_VISIBLE_DEVICES}"
    else
        echo ""
    fi
}

function habana_prompt_info(){
    if [[ ! -z "$HABANA_VISIBLE_MODULES" ]]; then
        echo "| %{$FG[141]%}habana:${HABANA_VISIBLE_MODULES}"
    else
        echo ""
    fi
}

PROMPT='\
%{$FG[153]%}%n\
%{$FG[255]%} at \
%{$FG[153]%}%m\
%{$FG[255]%} in \
%{$FG[153]%}${PWD/#$HOME/~}\
%{$reset_color%}\
 $(git_prompt_info)\
 $(cuda_prompt_info)\
 $(habana_prompt_info)
%{$fg_bold[blue]%}$ '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$FG[218]%}on "
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$FG[218]%}%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$FG[076]%} ○%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$FG[209]%} ✗%{$reset_color%}"

export PS1=$PROMPT
