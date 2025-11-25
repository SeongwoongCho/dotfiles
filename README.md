# dotfiles

Personal development environment configuration using Neovim, Zsh, and various tools.

## Quick Install

###  Install by cli command line
```bash
git clone git@github.com:SeongwoongCho/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash src/install.sh
```
### Install by Docker 
```bash
#!/bin/bash
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg USER_NAME=$(id -un) \
  -t ${IMAGE_NAME} .

bash run_docker.sh ${IMAGE_NAME} ${CONTAINER_NAME}
```

## Core Features

### 🖥️ Terminal Environment
- **Shell**: Zsh with Oh-My-Zsh
- **Theme**: TangoDark terminal color scheme
- **Font**: D2Coding Mono Hack (Nerd Font compatible)

### ⚡ Zsh Configuration
- **Theme**: mrtazz_custom
- **Plugins**: 
  - alias-tips
  - zsh-syntax-highlighting  
  - zsh-autosuggestions
- **Features**:
  - Custom LS_COLORS
  - FZF integration with fd
  - History with timestamps
  - Newline before each prompt

### 🚀 Neovim Setup (Lazy.nvim)
Modern Neovim configuration with LSP support and advanced features.

#### LSP Servers & Language Support
- **C/C++**: clangd with clang-tidy integration
- **Python**: pylsp + jedi_language_server (dual setup)
- **Lua**: lua_ls with Neovim-specific settings
- **Auto-installation**: Mason + mason-lspconfig

#### Key Plugins
- **telescope.lua**: Fuzzy finder and file navigation
- **nvim-cmp.lua**: Intelligent autocompletion with LSP
- **treesitter.lua**: Advanced syntax highlighting and parsing
- **gitsigns.lua**: Git integration with inline diff markers
- **formatter.lua**: Code formatting with configurable timeout
- **oceanic-next.lua**: Color scheme
- **snacks.lua + lualine.lua**: Modern UI components
- **nvim-tree.lua**: File explorer
- **markview.lua**: Enhanced markdown rendering
- **yanky.lua**: Enhanced yank/paste functionality
- **nvim-dap-ui.lua**: Debug adapter protocol UI  

## ⌨️ Key Bindings

### Leader Keys
- **Leader**: `,` (comma)
- **Local Leader**: `.` (period) - used for debugger

### Essential Shortcuts
- **`,R`**: Reload vimrc configuration
- **`@`**: Turn off search highlight  
- **`,s`**: Save current file
- **`F8`**: Toggle paste mode
- **`F9`**: Toggle line numbers

### Navigation & Buffers
- **`[b`** / **`]b`**: Previous/Next buffer
- **`,g`**: Go to previous location (after go-to-definition)

### Development Tools
- **`,b`** / **`,v`**: Insert Python ipdb breakpoint (above/below)
- **`=G`**: Auto-fix indentation

### Fuzzy Finding (Telescope)
- **`<C-p>`**: Find files by name
- **`<C-o>`**: Find files by content (live grep)

### Visual Mode
- **`<`** / **`>`**: Indent left/right while keeping selection

## 🔧 Installation Details

### Prerequisites
The installation script (`src/install.sh`) automatically handles:
- Oh-My-Zsh installation
- Neovim plugin management via Lazy.nvim
- LSP servers via Mason
- Required dependencies and libraries

## 🎨 Theme & Font Setup

### Terminal Configuration
- **Color Scheme**: TangoDark
- **Font**: D2Coding Mono (Nerd Font)
- **Font Features**: 
  - Ligature support
  - Powerline symbols
  - Nerd Font icons

### Neovim Color Scheme
- **Main Theme**: Oceanic Next
- **UI Components**: Modern statusline with lualine
- **Syntax**: Enhanced with Treesitter

## 🚨 Troubleshooting

### Common Issues
- **Special characters not displaying**: Install D2Coding Mono Hack Nerd Font
- **LSP not working**: Restart Neovim after initial setup for Mason to install servers
- **Formatter timeout**: Increased to 2000ms for better reliability

### Known Limitations  
- Image preview in Telescope may not work in all terminals
- Auto-indentation (`=G`) may have issues with complex comment blocks

### Codeium
Please run the following code in case codeium is not properly working. 

```
chown -R root:root ~/.cache/nvim/codeium
chmod -R 755 ~/.cache/nvim/codeium
```

## 📁 Project Structure

```
~/.dotfiles/
├── init.lua              # Neovim entry point
├── lua/
│   ├── config/           # Core configuration
│   │   ├── keymaps.lua   # Key mappings
│   │   ├── options.lua   # Neovim options  
│   │   └── lazy.lua      # Plugin manager setup
│   └── plugins/          # Plugin configurations
├── src/                  # Installation scripts
├── zshrc                 # Zsh configuration
└── assets/              # Color schemes and resources
```
