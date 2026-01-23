# dotfiles

Personal development environment configuration using Neovim, Zsh, Tmux, and AI tools.

## Quick Install

```bash
git clone git@github.com:SeongwoongCho/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash src/install.sh [profile]
```

### Installation Profiles

| Profile | Description | Use Case |
|---------|-------------|----------|
| `minimal` | zsh + nvim + git | Basic dev environment |
| `standard` | + tmux + LSP + plugins | Full local dev |
| `full` | + Claude Code + all LSPs | **Default** - Complete environment |

```bash
# Examples
bash src/install.sh minimal   # Lightweight setup
bash src/install.sh standard  # Without AI tools
bash src/install.sh           # Full (default)
```

### Docker Install

```bash
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg USER_NAME=$(id -un) \
  -t ${IMAGE_NAME} .

bash run_docker.sh ${IMAGE_NAME} ${CONTAINER_NAME}
```

## Project Structure

```
~/.dotfiles/
├── nvim/                    # Neovim configuration (Lazy.nvim)
│   ├── init.lua             # Entry point
│   └── lua/
│       ├── config/          # Core settings (keymaps, options)
│       └── plugins/         # Plugin configurations
├── zsh/
│   ├── zshrc                # Main shell config
│   └── zsh.d/               # Modular shell scripts
│       ├── 10-functions.zsh # Utility functions
│       ├── 20-aliases.zsh   # Common aliases
│       └── 30-git.zsh       # Git shortcuts
├── tmux/
│   ├── tmux.conf            # Tmux configuration
│   └── statusbar.tmux       # Dynamic status bar
├── git/
│   └── gitconfig            # Git settings
├── ssh/
│   └── config               # SSH configuration
├── assets/                  # Themes, colors, keymaps
└── src/                     # Installation scripts
    ├── install.sh           # Main installer (profile-based)
    ├── install-prerequisite.sh  # Dependencies
    ├── install-omz.sh       # Oh-My-Zsh
    └── cleanse.sh           # Cleanup script
```

## Core Features

### Terminal Environment
- **Shell**: Zsh with Oh-My-Zsh + zplug
- **Multiplexer**: Tmux with TPM (prefix: `Ctrl-A`)
- **Theme**: mrtazz_custom + Oceanic Next

### Zsh Plugins
- `alias-tips` - Reminds you of aliases
- `zsh-syntax-highlighting` - Command highlighting
- `zsh-autosuggestions` - Fish-like suggestions
- `fzf` + `fd` - Fuzzy finding

### Neovim (Lazy.nvim)

**LSP Support:**
- C/C++: clangd
- Python: pylsp + jedi_language_server
- Lua: lua_ls
- Auto-install via Mason

**Key Plugins:**
- `telescope.nvim` - Fuzzy finder
- `nvim-cmp` - Autocompletion
- `treesitter` - Syntax highlighting
- `gitsigns` - Git integration
- `nvim-dap-ui` - Debugging
- `codeium` - AI completion

### AI Tools (full profile)
- **Claude Code** with oh-my-claudecode plugin
- LSP plugins for multiple languages

## Key Bindings

### Leader Keys
- **Leader**: `,` (comma)
- **Local Leader**: `.` (period)

### Essential
| Key | Action |
|-----|--------|
| `,R` | Reload config |
| `,s` | Save file |
| `@` | Clear search highlight |
| `<C-p>` | Find files |
| `<C-o>` | Live grep |

### Navigation
| Key | Action |
|-----|--------|
| `[b` / `]b` | Previous/Next buffer |
| `,g` | Go back (after goto-definition) |
| `<C-h/j/k/l>` | Navigate splits (vim-tmux) |

### Tmux (prefix: Ctrl-A)
| Key | Action |
|-----|--------|
| `|` | Vertical split |
| `-` | Horizontal split |
| `r` | Reload config |
| `hjkl` | Navigate panes |

## Customization

### Adding New Zsh Modules
Create files in `zsh/zsh.d/` with numeric prefix:
- `10-19`: Functions
- `20-29`: Aliases
- `30-39`: Git

## Troubleshooting

### Common Issues
- **Special characters missing**: Install Nerd Font (D2Coding Mono Hack)
- **LSP not working**: Restart Neovim for Mason to install servers
- **Codeium permission error**:
  ```bash
  chown -R $(whoami):$(whoami) ~/.cache/nvim/codeium
  chmod -R 755 ~/.cache/nvim/codeium
  ```

### Cleanup
```bash
bash src/cleanse.sh  # Remove all dotfiles symlinks
```

## License

MIT
