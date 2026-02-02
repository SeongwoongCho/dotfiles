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
├── config/                  # Version management
│   ├── versions.sh          # Default versions + auto-detection
│   └── versions.d/          # Environment-specific overrides
│       ├── ubuntu-20.04.sh
│       ├── ubuntu-22.04.sh
│       ├── ubuntu-24.04.sh
│       └── local.sh         # Local overrides (gitignored)
└── src/                     # Installation scripts
    ├── install.sh           # Main installer (profile-based)
    ├── install-prerequisite.sh  # Dependencies
    ├── install-omz.sh       # Oh-My-Zsh
    ├── update.sh            # Update without rebuilding
    └── cleanse.sh           # Cleanup script
```

## Core Features

### Terminal Environment
- **Shell**: Zsh with Oh-My-Zsh + zplug
- **Multiplexer**: Tmux with TPM (prefix: `Ctrl-A`)
- **Theme**: mrtazz_custom + Oceanic Next
- **Auto-reload**: Changes to zshrc, themes, and zsh.d modules are automatically detected and applied

### Zsh Plugins
- `alias-tips` - Reminds you of aliases
- `zsh-syntax-highlighting` - Command highlighting
- `zsh-autosuggestions` - Fish-like suggestions
- `fzf` + `fd` - Fuzzy finding
- `zoxide` - Smarter cd command

### Modern CLI Tools
| Original | Replacement | Description |
|----------|-------------|-------------|
| `ls` | `eza` | Modern ls with colors and icons |
| `cd` | `z` (zoxide) | Smart directory jumping |
| `cat` | `batcat` | Syntax highlighting |
| `df` | `duf` | Disk usage with better UI |
| `grep` | `rg` (ripgrep) | Faster grep |
| `find` | `fd` | Faster find |

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
- `codeium` - AI completion

### AI Tools (full profile)
- **Claude Code** with oh-my-claudecode plugin
- **superpowers** plugin for enhanced workflows
- LSP plugins for multiple languages (TypeScript, Python, Go, Rust, C/C++, etc.)

## Utility Functions

### DNS Optimization (Docker)

Docker containers often have slow DNS resolution. This is automatically fixed during installation, but you can also run it manually:

```bash
fix-dns          # Diagnose and fix DNS latency
fix-dns --check  # Diagnose only (no changes)
fix-dns --force  # Fix without confirmation
```

### Oh-My-ClaudeCode Management

```bash
omcup            # Update OMC (CLAUDE.md, plugin, HUD)
omcup -f         # Force update all components
claude           # Launch Claude Code (auto-updates OMC first)
```

### Accelerator Device Selection

Set visible devices for hardware accelerators. Selected devices are displayed in the shell prompt.

| Command | Environment Variable | Prompt Display |
|---------|---------------------|----------------|
| `ug <ids>` / `usegpu` | `CUDA_VISIBLE_DEVICES` | `cuda:0,1` |
| `uh <ids>` / `usehpu` | `HABANA_VISIBLE_DEVICES` | `habana:0` |
| `um <ids>` / `usemaccel` | `MACCEL_VISIBLE_DEVICES` | `maccel:0,1` |

```bash
ug 0,1    # Use NVIDIA GPU 0 and 1
uh 0      # Use Intel Gaudi HPU 0
um 0      # Use Mobilint NPU 0
ug        # Clear selection (use all)
```

### Hardware Monitoring

Real-time monitoring aliases for accelerators. NPU usage is also displayed in tmux statusbar when `npustat` is available.

| Alias | Command | Description |
|-------|---------|-------------|
| `gpu` | `watch gpustat --color` | NVIDIA GPU monitoring |
| `gpusmi` | `watch nvidia-smi` | nvidia-smi output |
| `npu` | `watch npustat --color` | Mobilint NPU monitoring |
| `hpusmi` | `watch hl-smi` | Intel Gaudi HPU monitoring |

**Note:** `npustat` is a custom tool (similar to gpustat) installed from `~/.dotfiles/npustat`.

### Python Environment

Set PYTHONPATH easily. The path is displayed in the shell prompt when set.

| Command | Environment Variable | Prompt Display |
|---------|---------------------|----------------|
| `up <path>` | `PYTHONPATH` | `pypath:~/project` |

```bash
up .          # Set PYTHONPATH to current directory
up /path/to   # Set PYTHONPATH to specified path
up            # Clear PYTHONPATH
```

### Other Functions

| Function | Description |
|----------|-------------|
| `pyclean` | Remove Python cache files |
| `howmany <dir> "*.ext"` | Count files matching pattern |
| `fuzzyvim` | Open file with fzf + vim |
| `buo <files>` | Backup files before overwriting |

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

## Update (Without Rebuilding Docker)

Update dotfiles when remote repository changes, without rebuilding Docker image.

### Quick Commands

| Command | Description |
|---------|-------------|
| `dotup` | Fast update (git pull + relink + plugins) |
| `dotup-full` | Full update (includes system packages) |
| `dotup --versions` | Show current version configuration |
| `dotcd` | Navigate to dotfiles directory |
| `omcup` | Update Oh-My-ClaudeCode components |
| `omcup -f` | Force update all OMC components |

### What Each Command Does

```bash
dotup              # Daily use - quick sync
├── git pull
├── Relink symlinks (zshrc, gitconfig, nvim, tmux...)
├── Detect version config changes → warn if --packages needed
├── Sync Neovim plugins (Lazy)
├── Update Tmux plugins (TPM)
└── Update Zplug plugins

dotup-full         # When packages changed
├── (all above)
└── Reinstall system packages with version management
```

### Usage Examples

```bash
# Regular update
dotup

# After install-prerequisite.sh changed
dotup --packages

# Check versions before updating
dotup --versions

# Override specific version
VERSION_NEOVIM=v0.9.5 dotup --packages

# Apply changes to current shell
source ~/.zshrc  # or: exec zsh
```

## Version Management

Package versions are managed per-environment to ensure compatibility.

### How It Works

```
config/versions.sh           # Default versions
         ↓
config/versions.d/ubuntu-22.04.sh   # OS-specific override
         ↓
config/versions.d/local.sh   # Machine-specific (gitignored)
         ↓
Environment variable         # Highest priority
```

### Managed Packages

| Package | Why Managed |
|---------|-------------|
| Neovim | Ubuntu repo version too old, built from source |
| Lua/Luarocks | Specific version needed for plugins |
| Node.js | Major version for compatibility |
| VSCode C++ Tools | Downloaded from GitHub releases |
| thefuck | Requires specific Python version |

**Note:** apt packages use Ubuntu defaults (tested for that release).

### Adding New Environment

```bash
# Create override for new Ubuntu version
cat > config/versions.d/ubuntu-26.04.sh << 'EOF'
#!/bin/bash
export VERSION_NEOVIM="v0.12.0"
export VERSION_THEFUCK_PYTHON="3.13"
EOF
```

### Local Overrides

```bash
# Machine-specific settings (not tracked by git)
cat > config/versions.d/local.sh << 'EOF'
#!/bin/bash
export VERSION_NEOVIM="v0.9.5"  # Use older version on this machine
EOF
```

## Troubleshooting

### Common Issues

- **Claude Code slow in Docker**: DNS resolution delay. Run `fix-dns` or check manually:
  ```bash
  # Diagnose
  curl -w "DNS: %{time_namelookup}s\n" -o /dev/null -s https://api.anthropic.com

  # Fix (if DNS > 1s)
  fix-dns --force
  ```

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
