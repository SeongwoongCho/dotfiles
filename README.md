# dotfiles

## Usage

```bash
git clone git@github.com:SeongwoongCho/dotfiles.git ~/.dotfiles; cd ~/.dotfiles; bash src/install.sh;
```

## Features | Plugins
- ZSH features & plugins (see `zshrc` file) 
    - oh-my-zsh, alias-tips, zsh-syntax-highlighting, zsh-autosuggestions
- VIM features & Plugins (see `lua/plugins` directory)
    - ale.lua : Asynchronous Lint Engine for vim (removing trailing white spaces, PEP8 checker, import order fixer, etc.)
    - avante.lua : Cursor-style AI assistant for vim
        - I currently only consider 'copilot', which is installed automatically along with avante, and you have to input ':Copilot Setup' for authentication. 
    - telescope.lua: Advanced Fuzzy finder for vim (seems to be better than ctrlp)
    - snacks.lua, vim-airline.lua, oceanic-next.lua: UI for vim
    - treesitter.lua: Syntax parser for vim
    - jedi-vim.lua: Python autocompletion for vim
    - render-markdown.lua: rendering markdown in the vim 
- lazy-lock.json : Contains verified version of plugins  

## VIM Key bindings
- Basic shortcuts
    - F2 : turn off search highlight
    - F3 : turn on search highlight based on keyword at current cursor position
    - F4 : trailing whitespaces from all lines
    - F5 : turn on PEP8 checker
    - F6 : turn off PEP8 checker
    - F8 : paste toggle (on/off)
    - F9 : toggle line number (useful when copying a block of lines without line numbers)
    - =G : auto fix indentation (sometimes not working under the codes with comments)

- Avante shortscuts
    - ? : toggle avante sidebar (AI assistant) on/off
    - \> : Switch from code / sidebar to sidebar / code
    - tab : switch panes in sidebar.
    - ]], [[ : jump to next/previous provided (by the AI) code block (function, class, etc.)
    - ]x, [x : jump to next/previous conflicts 

- FuzzyFinding
    - <C-p> : fuzzy find file by name
    - <C-o> : fuzzy find file by content

- ...

## Infos
- terminal info (iterm 2): <br>
    - type: xterm <br>
    - colorscheme: New Black <br>
    - font: Hack Nerd Font  
    - font quality: Natural ClearType
    - bold: Use bold color and font

## Trouble shooting 
- All special characters are not displayed properly in the terminal. <br>
    - Solution: Change the font to 'Hack Nerd Font'.

## TODOs
- fix treesitter for python parser. -- fix by disabling treesitter for python.
- image preview is not working in Telescope.
- auto fixing indentation by '=G' does not work sometimes.
- <F9> toggle line number is not working properly. -- numberwidth for linenumber is remained.
- Avante Toggle ("?") automatically enters INSERT mode. -- fixed by adding 'normal' mode after entering INSERT mode.
- Add jupyter lab configuration.
