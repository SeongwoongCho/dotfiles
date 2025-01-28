" =============== plugins ============= "
call plug#begin()
Plug 'flazz/vim-colorschemes'
Plug 'preservim/NERDTree'
Plug 'davidhalter/jedi-vim'
Plug 'dense-analysis/ale'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-commentary'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'mhartington/oceanic-next'
Plug 'github/copilot.vim'
Plug 'junegunn/fzf'
call plug#end()

" =============== general ============= "
if filereadable('/bin/zsh')
  set shell=/bin/zsh
endif

syntax on					" syntax highligting
set nocompatible
set cursorline              " highlight current cursorline
set ruler		            " show row/col info
set number				    " show line numbers

" indentation
set backspace=eol,start,indent
set autoindent
set smartindent

" tab settings
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

" searchf
set ignorecase              " case-insensitive by default
set smartcase               " case-sensitive if keyword contains both uppercase and lowercase
set incsearch	            " incremental search
set hlsearch				" highlight search keyword

" color settings
set t_Co=256
set t_ut=
set background=dark

" colorscheme xoria256
" colorscheme afterglow 

" set termguicolors     " enable true colors support
" let ayucolor="light"  " for light version of theme
" let ayucolor="mirage" " for mirage version of theme
" let ayucolor="dark"   " for dark version of theme
" colorscheme ayu

syntax enable
set t_Co=256
if (has("termguicolors"))
set termguicolors
endif
let g:oceanic_next_terminal_bold = 1
let g:oceanic_next_terminal_italic = 1
colorscheme OceanicNext

" copy-paste
set pastetoggle=<F8>		                " this will disable auto indent when pasting
autocmd InsertLeave * silent! set nopaste   " unset paste when leaving insert mode

" misc
set visualbell
set history=1000
set undolevels=1000
set noswapfile
set nobackup
set nowrap                  " no line wrapping
set textwidth=0             " no line wrapping
set splitbelow              " split bottom window if needed
set lazyredraw              " don't update screen during macro and script execution
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o " no auto comment when inserting newline 


" =============== functional ============= "
let mapleader=","           " comma is the <Leader> key.
let maplocalleader=","      " comma : <LocalLeader>

nnoremap <leader>R :so $MYVIMRC<CR> " reload vimrc in current vim
" nnoremap <F2> :noh<CR>              " turn off search highlight until the next search
nnoremap @ :noh<CR>              " turn off search highlight until the next search
nnoremap <F9> :set invnumber<CR>    " toggle line number (for the sake of copying text without line numbers)
nnoremap <leader>s :w<CR>           " write/save

nnoremap [b  :bprevious<CR> " go to the previous buffer 
nnoremap ]b  :bnext<CR>     " go to the next buffer
set hidden                  " enable switching across buffers without saving.

" https://superuser.com/questions/310417/how-to-keep-in-visual-mode-after-identing-by-shift-in-vim
:vnoremap < <gv             " keep in visual mode while indenting
:vnoremap > >gv             " (")

" ipdb
:nnoremap <Leader>b Oimport os; import ipdb; ipdb.set_trace(context=15)<Esc>
:nnoremap <Leader>v oimport os; import ipdb; ipdb.set_trace(context=15)<Esc>


" =============== plugins ============= "
" nerdtree
"" browse file tree
"map <Leader>N :NERDTreeToggle<CR>
map " :NERDTreeToggle<CR>
set encoding=utf-8 " fix the issue of being unable to open files outside current directory

" youcompleteme
""let g:ycm_add_preview_to_completeopt = 1
""let g:ycm_autoclose_preview_window_after_completion = 1
""let g:ycm_autoclose_preview_window_after_insertion = 1

" jedi-vim
" https://github.com/davidhalter/jedi-vim/blob/master/doc/jedi-vim.txt
let g:jedi#goto_command="<leader>d"
let g:jedi#goto_assignments_command="<leader>g"
let g:jedi#completions_enabled=1
let g:jedi#show_call_signatures=1 " argument hints 
let g:jedi#show_call_signatures_delay=50
let g:jedi#use_tabs_not_buffers=0
let g:jedi#smart_auto_mappings=0
let g:jedi#popup_on_dot = 0
let g:jedi#show_call_signatures = "1"
let g:jedi#auto_close_doc = 1
autocmd FileType python setlocal completeopt-=preview

" airline
" https://github.com/vim-airline/vim-airline#smarter-tab-line
let g:airline#extensions#tabline#enabled=1
let g:airline#extensions#tabline#show_buffers=1
let g:airline#extensions#tabline#formatter='unique_tail' " 
let g:airline_theme='bubblegum'
let g:airline_section_b = '%{strftime("%a %H:%M:%S %Y-%m-%d")}'
set laststatus=2                " turn on bottom bar

" Ale
" Ale (python)
"https://git.pyrokinesis.fr/darkgeem/chezmoi/-/blob/c800f8dc4e8c13b747c1b199ddb297787a2ebb5d/dot_vimrc
" PEP8 ignores:
" (E501) Line too long (>79 characters)
let g:ale_python_flake8_options="--ignore=E501"
" (E701) multiple statements on one line (colon)
let g:ale_python_flake8_options.=",E701"
" (E702) multiple statements on one line (semi colon)
let g:ale_python_flake8_options.=",E702"

let g:ale_python_pylint_executable=''
let g:ale_fix_on_save = 1
let g:ale_fixers={'python': ['remove_trailing_lines','trim_whitespace', 'isort']}

" remove trailing whitespaces from all lines
" https://vi.stackexchange.com/questions/454/whats-the-simplest-way-to-strip-trailing-whitespace-from-all-lines-in-a-file
nnoremap <F4> :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar><CR>

" ctrlp.vim
set runtimepath^=~/.vim/bundle/ctrlp.vim
" -- https://seulcode.tistory.com/275
set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux
" set wildignore+=*\\tmp\\*,*.swp,*.zip,*.exe  " Windows
let g:ctrlp_user_command = ['.git/', 'git --git-dir=%s/.git ls-files -oc --exclude-standard']       "Ignore in .gitignore
let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|git'                                           "Ignore node_modules
let g:ctrlp_custom_ignore = {
  \ 'file': '\v\.(pyc|so|dll)$',
  \ }
" --

set clipboard+=unnamedplus
