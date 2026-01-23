#!/bin/zsh
# AI tools integration

# OpenCode AI assistant
function askai() {
    opencode run "$*" --model opencode/big-pickle
}
