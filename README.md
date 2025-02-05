# dotfiles

## Usage
```
git clone https://github.com/SeongwoongCho/dotfiles.git ~/.dotfiles; cd ~/.dotfiles; bash src/install.sh;
```

## Features | Plugins
- ZSH features & plugins (see `zshrc` file) 
    - oh-my-zsh, alias-tips, zsh-syntax-highlighting, zsh-autosuggestions
- VIM features & Plugins (see `lua/plugins` directory)
    - ale.lua : Asynchronous Lint Engine for vim
    - avante.lua : Cursor-style AI assistant for vim
        - I currently only consider 'copilot', which is installed automatically along with avante, and you have to input ':Copilot Setup' for authentication. 
    - image.lua: Image viewer for vim
    - telescope.lua: Advanced Fuzzy finder for vim (seems to be better than ctrlp)
    - snacks.lua, vim-airline.lua, oceanic-next.lua: UI for vim
    - treesitter.lua: Syntax parser for vim
    - jedi-vim.lua: Python autocompletion for vim
    - render-markdown.lua: rendering markdown in the vim 

## VIM Key bindings
- Basic shortcuts
    - F2 : turn off search highlight
    - F3 : turn on search highlight based on keyword at current cursor position
    - F4 : trailing whitespaces from all lines
    - F5 : turn on PEP8 checker
    - F6 : turn off PEP8 checker
    - F8 : paste toggle (on/off)
    - F9 : toggle line number (useful when copying a block of lines without line numbers)

- Avante shortscuts
    - ? : toggle avante sidebar (AI assistant) on/off
    - \> : Switch from code / sidebar to sidebar / code
    - tab : switch panes in sidebar.
    - ]], [[ : jump to next/previous provided (by the AI) code block (function, class, etc.)
    - ]x, [x : jump to next/previous conflicts 

- FuzzyFinding
    - <C-p> : fuzzy find file by name
    - <C-o> : fuzzy find file by content

## Miscellaneous
- terminal info: <br>
    - type: xterm <br>
    - colorscheme: New Black <br>
    - font: DejaVu Sans Mono (size: 10)
    - asian font: DejaVu Sans Mono (size: 10)
    - font quality: Natural ClearType
    - bold: Use bold color and font

## TODOs
- fix treesitter for python parser.
- image preview is not working (in Telescope).
- auto fixing indentation by '=G' does not work sometimes.
- Width of avante sidebar is not adjusted.
- rending markdown is not working --> Avante sidebar is not hard to recognize.
- Paste under the normal mode is not working properly. (indentation problem) 
- <F9> toggle line number is not working properly. (useless indentation is remained)
