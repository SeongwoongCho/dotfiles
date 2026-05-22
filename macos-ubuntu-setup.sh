#!/usr/bin/env bash
# macos-ubuntu-setup.sh
# Transform Ubuntu GNOME desktop into a macOS-like environment using
# the WhiteSur theme suite (vinceliuice) + GNOME extensions.
#
# Tested target: Ubuntu 26.04 / GNOME Shell 50.x (Wayland or X11).
# Idempotent: safe to re-run; skips work that is already done.
#
# Usage:
#   bash ~/.dotfiles/macos-ubuntu-setup.sh                # full install
#   bash ~/.dotfiles/macos-ubuntu-setup.sh --post-relogin # finish after logout/login
#   bash ~/.dotfiles/macos-ubuntu-setup.sh --uninstall    # revert
#   bash ~/.dotfiles/macos-ubuntu-setup.sh --skip-extensions
#
# After completion: log out and log back in (or reboot) so GNOME Shell
# picks up the new shell theme and extensions.

set -euo pipefail

# ---------- config ----------
WORK_DIR="${HOME}/.cache/whitesur-src"
GTK_REPO="https://github.com/vinceliuice/WhiteSur-gtk-theme.git"
ICON_REPO="https://github.com/vinceliuice/WhiteSur-icon-theme.git"
CURSOR_REPO="https://github.com/vinceliuice/WhiteSur-cursors.git"
WALL_REPO="https://github.com/vinceliuice/WhiteSur-wallpapers.git"

# Extension UUIDs (extensions.gnome.org)
EXT_USER_THEMES="user-theme@gnome-shell-extensions.gcampax.github.com"
EXT_DASH_TO_DOCK="dash-to-dock@micxgx.gmail.com"
EXT_BLUR_MY_SHELL="blur-my-shell@aunetx"
EXT_MAC_HOVER="macos-fullscreen-hover@local"
EXT_JUST_PERFECTION="just-perfection-desktop@just-perfection"

# Font choices: prefer Apple SF Pro (installed by this script) with Inter as fallback.
FONT_NAME="SF Pro Display 11"
FONT_DOCUMENT="SF Pro Text 11"
FONT_TITLEBAR="SF Pro Display Semibold 11"

# Theme + variant choices
THEME_NAME="WhiteSur-Dark"      # GTK + shell theme
ICON_NAME="WhiteSur-dark"       # Icons
CURSOR_NAME="WhiteSur-cursors"  # Cursors

# ---------- helpers ----------
log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[X]\033[0m %s\n' "$*" >&2; exit 1; }

require_gnome() {
    [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] \
        || die "This script targets GNOME. Detected: ${XDG_CURRENT_DESKTOP:-unknown}"
}

refuse_root() {
    if [[ $EUID -eq 0 ]]; then
        die "Run as your normal user, not root/sudo. The script will call sudo itself when needed (so themes install into your home, not /root)."
    fi
}

ensure_apt_packages() {
    local pkgs=(
        git sassc make
        gnome-tweaks
        gnome-shell-extension-manager
        gettext
        libglib2.0-dev-bin
        fonts-inter
        dbus-x11
        x11-utils
    )
    local missing=()
    for p in "${pkgs[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if (( ${#missing[@]} == 0 )); then
        ok "apt prerequisites already installed"
        return
    fi
    log "Installing apt packages: ${missing[*]}"
    # Don't fail on broken third-party sources; the packages we need are in
    # the official Ubuntu repos and will install fine.
    sudo apt-get update -y || warn "apt update reported errors (likely a broken third-party repo); continuing"
    sudo apt-get install -y "${missing[@]}"
}

clone_or_update() {
    local url="$1" dest="$2"
    if [[ -d "$dest/.git" ]]; then
        log "Updating $(basename "$dest")"
        git -C "$dest" pull --ff-only --quiet || warn "git pull failed for $dest"
    else
        log "Cloning $(basename "$dest")"
        git clone --depth=1 "$url" "$dest"
    fi
}

install_gtk_theme() {
    local src="$WORK_DIR/WhiteSur-gtk-theme"
    clone_or_update "$GTK_REPO" "$src"
    log "Installing GTK + GNOME Shell theme (WhiteSur)"
    # -c Dark         : dark variant
    # -t default      : default accent (blue)
    # -l              : also tweak libadwaita (GTK4 apps)
    # -N glassy       : translucent nautilus sidebar
    # -m              : monterey style
    bash "$src/install.sh" -c Dark -t default -l -N glassy -m
    # Firefox theme (Monterey) -- works for both standard and Snap Firefox
    if command -v firefox >/dev/null 2>&1 \
        || [[ -d "$HOME/.mozilla/firefox" ]] \
        || [[ -d "$HOME/snap/firefox/common/.mozilla/firefox" ]]; then
        log "Applying Firefox Monterey theme"
        pkill -x firefox       2>/dev/null && sleep 2 || true
        pkill -x firefox-bin   2>/dev/null && sleep 1 || true
        bash "$src/tweaks.sh" -f monterey || warn "Firefox tweak skipped"
        configure_firefox_toolbar
    fi
    # Dash-to-Dock theme integration (only effective if DTD is enabled)
    log "Applying WhiteSur Dash-to-Dock theme integration"
    bash "$src/tweaks.sh" -d || warn "dash-to-dock tweak skipped"
    # GDM (login screen) theme — needs sudo because it writes to /usr/share.
    log "Installing WhiteSur GDM (login screen) theme"
    sudo bash "$src/tweaks.sh" -g || warn "GDM theme install failed"
    # Flatpak integration — per-user override, do NOT use sudo. Requires flatpak.
    if command -v flatpak >/dev/null 2>&1; then
        log "Connecting WhiteSur to flatpak apps"
        bash "$src/tweaks.sh" -F || warn "flatpak tweak failed"
    else
        log "flatpak not installed; skipping flatpak integration"
    fi
}

install_icons() {
    local src="$WORK_DIR/WhiteSur-icon-theme"
    clone_or_update "$ICON_REPO" "$src"
    log "Installing WhiteSur icons"
    bash "$src/install.sh" -a   # all color variants
}

install_cursors() {
    local src="$WORK_DIR/WhiteSur-cursors"
    clone_or_update "$CURSOR_REPO" "$src"
    log "Installing WhiteSur cursors"
    bash "$src/install.sh"
}

install_wallpapers() {
    local src="$WORK_DIR/WhiteSur-wallpapers"
    clone_or_update "$WALL_REPO" "$src"
    log "Installing macOS wallpapers (WhiteSur dark, 4k)"
    # -t theme (whitesur|monterey|ventura|sonoma), -c color, -s screen
    bash "$src/install-wallpapers.sh" -t whitesur -c dark -s 4k
}

install_extensions() {
    if ! command -v gnome-extensions >/dev/null; then
        warn "gnome-extensions CLI missing; skipping extension auto-install"
        return
    fi
    # Try gext (gnome-extensions-cli) if available, else fall back to manual
    if ! command -v gext >/dev/null 2>&1; then
        log "Installing gnome-extensions-cli (gext) via pipx"
        if command -v pipx >/dev/null 2>&1; then
            pipx install gnome-extensions-cli || warn "pipx install failed"
        else
            sudo apt-get install -y pipx && pipx install gnome-extensions-cli \
                || warn "could not install gext; install extensions manually via Extension Manager"
        fi
    fi
    if command -v gext >/dev/null 2>&1; then
        log "Installing GNOME extensions (will be enabled after relogin)"
        gext install "$EXT_USER_THEMES"
        gext install "$EXT_DASH_TO_DOCK"
        gext install "$EXT_BLUR_MY_SHELL"
        # Try to enable now; if Shell hasn't rescanned, --post-relogin handles it.
        gnome-extensions enable "$EXT_USER_THEMES"   2>/dev/null || true
        gnome-extensions enable "$EXT_DASH_TO_DOCK"  2>/dev/null || true
        gnome-extensions enable "$EXT_BLUR_MY_SHELL" 2>/dev/null || true
    else
        warn "Open 'Extension Manager' and install: User Themes, Dash to Dock, Blur My Shell"
    fi
}

install_sf_pro_fonts() {
    local src="$WORK_DIR/San-Francisco-Pro-Fonts"
    clone_or_update "https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts.git" "$src"
    log "Installing SF Pro fonts"
    mkdir -p "$HOME/.local/share/fonts/SF-Pro"
    cp "$src"/*.otf "$HOME/.local/share/fonts/SF-Pro/"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null
}

install_panel_extensions() {
    if ! command -v gext >/dev/null 2>&1; then
        warn "gext missing; install panel extensions manually"
        return
    fi
    log "Installing Just Perfection extension"
    gext install "$EXT_JUST_PERFECTION"  2>/dev/null || true
    gnome-extensions enable "$EXT_JUST_PERFECTION" 2>/dev/null || true
}

configure_just_perfection() {
    local d="$HOME/.local/share/gnome-shell/extensions/$EXT_JUST_PERFECTION/schemas"
    [[ -f "$d/gschemas.compiled" ]] || { warn "Just Perfection schema missing"; return; }
    log "Configuring panel (clock on right, hide Activities button)"
    local s='org.gnome.shell.extensions.just-perfection'
    GSETTINGS_SCHEMA_DIR="$d" gsettings set $s clock-menu-position 1   # right
    GSETTINGS_SCHEMA_DIR="$d" gsettings set $s activities-button false
}

install_plymouth_theme() {
    if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
        log "Installing plymouth (apt)"
        sudo apt-get install -y plymouth plymouth-themes \
            || { warn "plymouth apt install failed"; return; }
    fi
    local src="$WORK_DIR/MacOS-Boot-Plymouth"
    clone_or_update "https://github.com/nilotpalbiswas/MacOS-Boot-Plymouth.git" "$src"
    log "Installing macOS Plymouth boot splash"
    sudo cp -r "$src/apple-mac-plymouth" /usr/share/plymouth/themes/
    sudo plymouth-set-default-theme -R apple-mac-plymouth \
        || warn "plymouth-set-default-theme failed (may need 'sudo update-initramfs -u')"
}

install_grub_theme() {
    if [[ ! -d /boot/grub ]] && [[ ! -d /boot/grub2 ]]; then
        log "GRUB not present; skipping GRUB theme"
        return
    fi
    local src="$WORK_DIR/WhiteSur-grub-theme"
    clone_or_update "https://github.com/vinceliuice/grub2-themes.git" "$src"
    log "Installing WhiteSur GRUB theme (4k)"
    sudo bash "$src/install.sh" -t whitesur -i whitesur -s 4k -b \
        || warn "GRUB theme install failed"
}

configure_firefox_toolbar() {
    # WhiteSur Monterey expects a single-row layout: nav buttons + URL bar +
    # tabs all in TabsToolbar. By default Firefox keeps URL bar in nav-bar,
    # which causes the first tab to overlap the URL bar.
    # This patches browser.uiCustomization.state in each profile's prefs.js.
    local profile_root
    for profile_root in \
        "$HOME/snap/firefox/common/.mozilla/firefox" \
        "$HOME/.mozilla/firefox"; do
        [[ -d "$profile_root" ]] || continue
        local p
        for p in "$profile_root"/*.default*; do
            [[ -d "$p" && -f "$p/prefs.js" ]] || continue
            log "Patching Firefox toolbar layout in $p"
            cp "$p/prefs.js" "$p/prefs.js.bak-whitesur-$(date +%s)"
            FIREFOX_PROFILE="$p" python3 - <<'PY'
import json, os, pathlib, re, sys
p = pathlib.Path(os.environ["FIREFOX_PROFILE"]) / "prefs.js"
text = p.read_text()
m = re.search(r'user_pref\("browser\.uiCustomization\.state",\s*"(.*?)"\);\s*\n', text)
if not m:
    sys.exit(0)  # nothing to patch
state = json.loads(m.group(1).encode().decode("unicode_escape"))
pl = state["placements"]
nav = pl.get("nav-bar", [])
target = [
    "sidebar-button","back-button","forward-button","stop-reload-button",
    "urlbar-container",
    "tabbrowser-tabs","new-tab-button","alltabs-button",
    "downloads-button","unified-extensions-button","fxa-toolbar-menu-button",
]
pl["TabsToolbar"] = target
pl["nav-bar"] = [x for x in nav if x not in target]
new_json = json.dumps(state, separators=(",", ":"))
escaped = new_json.replace("\\", "\\\\").replace('"', '\\"')
p.write_text(text[:m.start()] + f'user_pref("browser.uiCustomization.state", "{escaped}");\n' + text[m.end():])
PY
        done
    done
}

install_mac_hover_extension() {
    # Write a small custom GNOME Shell extension that briefly un-fullscreens
    # the focused window when the cursor enters the top edge of the screen,
    # so the headerbar (with traffic-light buttons) reappears — like macOS.
    local dest="$HOME/.local/share/gnome-shell/extensions/$EXT_MAC_HOVER"
    log "Installing macOS-fullscreen-hover extension"
    mkdir -p "$dest"
    cat >"$dest/metadata.json" <<'JSON'
{
  "uuid": "macos-fullscreen-hover@local",
  "name": "macOS Fullscreen Hover Headerbar",
  "description": "When a window is fullscreen, hovering near the top edge briefly unmaximizes it so the headerbar (with close/min/max controls) becomes visible — like macOS fullscreen menubar reveal.",
  "shell-version": ["45", "46", "47", "48", "49", "50"],
  "version": 1,
  "url": "local"
}
JSON
    cat >"$dest/extension.js" <<'JS'
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const TRIGGER_HEIGHT = 5;
const HIDE_BELOW = 60;
const POLL_INTERVAL_MS = 50;

export default class MacosFullscreenHover extends Extension {
    enable() {
        this._triggers = [];
        this._revealedWindow = null;
        this._pollerId = 0;
        this._trackedWindow = null;
        this._trackedWindowFsId = 0;
        this._monitorsId = Main.layoutManager.connect(
            'monitors-changed', () => this._rebuildTriggers());
        this._focusId = global.display.connect(
            'notify::focus-window', () => this._onFocusChanged());
        this._rebuildTriggers();
        this._onFocusChanged();
    }
    disable() {
        if (this._monitorsId) { Main.layoutManager.disconnect(this._monitorsId); this._monitorsId = 0; }
        if (this._focusId) { global.display.disconnect(this._focusId); this._focusId = 0; }
        this._disconnectTrackedWindow();
        this._stopPoller();
        this._removeTriggers();
        if (this._revealedWindow) {
            try { this._revealedWindow.make_fullscreen(); } catch (_) {}
            this._revealedWindow = null;
        }
    }
    _rebuildTriggers() {
        this._removeTriggers();
        for (const m of Main.layoutManager.monitors) {
            const t = new Clutter.Actor({
                reactive: false, x: m.x, y: m.y,
                width: m.width, height: TRIGGER_HEIGHT, opacity: 0,
            });
            t.connect('enter-event', () => {
                this._revealFocusedFullscreen();
                return Clutter.EVENT_PROPAGATE;
            });
            Main.layoutManager.addTopChrome(t);
            this._triggers.push(t);
        }
        this._updateTriggersState();
    }
    _removeTriggers() {
        for (const t of this._triggers) { try { t.destroy(); } catch (_) {} }
        this._triggers = [];
    }
    _updateTriggersState() {
        const win = global.display.focus_window;
        const armed = !!(win && win.is_fullscreen() && !this._revealedWindow);
        for (const t of this._triggers) { t.reactive = armed; t.visible = armed; }
    }
    _onFocusChanged() {
        this._disconnectTrackedWindow();
        const win = global.display.focus_window;
        if (win) {
            this._trackedWindow = win;
            this._trackedWindowFsId = win.connect(
                'notify::fullscreen', () => this._updateTriggersState());
        }
        this._updateTriggersState();
    }
    _disconnectTrackedWindow() {
        if (this._trackedWindow && this._trackedWindowFsId) {
            try { this._trackedWindow.disconnect(this._trackedWindowFsId); } catch (_) {}
        }
        this._trackedWindow = null;
        this._trackedWindowFsId = 0;
    }
    _revealFocusedFullscreen() {
        const win = global.display.focus_window;
        if (!win || !win.is_fullscreen() || this._revealedWindow) return;
        this._revealedWindow = win;
        try { win.unmake_fullscreen(); } catch (_) {}
        this._updateTriggersState();
        this._startPoller();
    }
    _startPoller() {
        if (this._pollerId) return;
        this._pollerId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT, POLL_INTERVAL_MS, () => {
                const win = this._revealedWindow;
                if (!win) { this._pollerId = 0; return GLib.SOURCE_REMOVE; }
                let ok = true;
                try { if (!win.get_compositor_private()) ok = false; } catch (_) { ok = false; }
                if (!ok) {
                    this._revealedWindow = null;
                    this._updateTriggersState();
                    this._pollerId = 0;
                    return GLib.SOURCE_REMOVE;
                }
                const [, , y] = global.get_pointer();
                if (y > HIDE_BELOW) {
                    try { win.make_fullscreen(); } catch (_) {}
                    this._revealedWindow = null;
                    this._updateTriggersState();
                    this._pollerId = 0;
                    return GLib.SOURCE_REMOVE;
                }
                return GLib.SOURCE_CONTINUE;
            });
    }
    _stopPoller() {
        if (this._pollerId) { try { GLib.source_remove(this._pollerId); } catch (_) {} this._pollerId = 0; }
    }
}
JS
    gnome-extensions enable "$EXT_MAC_HOVER" 2>/dev/null || true
}

install_shallow_headerbar_css() {
    # Inject CSS to make GTK app headerbars thin (~28px) like macOS.
    # Idempotent: replaces any prior block delimited by our markers.
    log "Patching gtk.css for shallow (macOS-like) headerbars"
    local css
    read -r -d '' css <<'CSS' || true
/* MACOS-SHALLOW-HEADERBAR begin */
headerbar,
headerbar.titlebar,
.titlebar:not(.default-decoration),
window > headerbar,
window > .titlebar {
  min-height: 28px !important;
  padding-top: 0 !important;
  padding-bottom: 0 !important;
}
/* Only shrink regular header buttons; do NOT touch windowcontrols
   (close/min/max traffic lights) — let the WhiteSur theme size them. */
headerbar button:not(.titlebutton):not(.image-button.close):not(.image-button.minimize):not(.image-button.maximize),
headerbar.titlebar button:not(.titlebutton),
.titlebar button:not(.titlebutton) {
  min-height: 22px !important;
  padding: 2px 6px !important;
  margin: 2px !important;
}
headerbar entry,
.titlebar entry {
  min-height: 22px !important;
}
/* MACOS-SHALLOW-HEADERBAR end */
CSS
    local f
    for f in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"; do
        mkdir -p "$(dirname "$f")"
        touch "$f"
        sed -i '/MACOS-SHALLOW-HEADERBAR begin/,/MACOS-SHALLOW-HEADERBAR end/d' "$f"
        printf "\n%s\n" "$css" >> "$f"
    done
}

configure_dash_to_dock() {
    local s='org.gnome.shell.extensions.dash-to-dock'
    gsettings list-schemas 2>/dev/null | grep -q "^$s$" || {
        warn "Dash-to-Dock schema not found yet; rerun after enabling the extension"
        return
    }
    log "Configuring Dash to Dock to look macOS-like"
    gsettings set $s dock-position BOTTOM
    gsettings set $s extend-height false
    gsettings set $s dash-max-icon-size 48
    gsettings set $s transparency-mode FIXED
    gsettings set $s background-opacity 0.50
    gsettings set $s running-indicator-style DOTS
    gsettings set $s show-trash true
    gsettings set $s show-mounts false
    gsettings set $s click-action minimize
    # Always-hidden, reveal on cursor hover at screen edge (macOS-like)
    gsettings set $s dock-fixed false
    gsettings set $s autohide true
    gsettings set $s intellihide false
    gsettings set $s require-pressure-to-show false
    gsettings set $s autohide-in-fullscreen true
    gsettings set $s animation-time 0.2
    gsettings set $s hide-delay 0.2
    gsettings set $s show-delay 0.1
}

apply_gsettings() {
    log "Applying desktop look (theme, icons, cursor, font, window buttons)"
    gsettings set org.gnome.desktop.interface gtk-theme        "$THEME_NAME"
    gsettings set org.gnome.desktop.interface icon-theme       "$ICON_NAME"
    gsettings set org.gnome.desktop.interface cursor-theme     "$CURSOR_NAME"
    gsettings set org.gnome.desktop.interface font-name           "$FONT_NAME"
    gsettings set org.gnome.desktop.interface document-font-name  "$FONT_DOCUMENT"
    gsettings set org.gnome.desktop.wm.preferences titlebar-font  "$FONT_TITLEBAR"
    gsettings set org.gnome.desktop.interface color-scheme     'prefer-dark'
    gsettings set org.gnome.desktop.wm.preferences theme       "$THEME_NAME"
    # Move window buttons (close/min/max) to the LEFT — macOS style
    gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
    # Alt+Enter toggles fullscreen; headerbar reveal-on-hover is handled by
    # the local macos-fullscreen-hover extension.
    gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "[]"
    gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Alt>Return']"
    # Shell theme requires User Themes extension to be enabled
    if gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.shell.extensions.user-theme$'; then
        gsettings set org.gnome.shell.extensions.user-theme name "$THEME_NAME"
    else
        warn "User Themes schema not loaded yet — set shell theme via gnome-tweaks after re-login"
    fi
}

uninstall() {
    log "Reverting to default GNOME look"
    gsettings reset org.gnome.desktop.interface gtk-theme
    gsettings reset org.gnome.desktop.interface icon-theme
    gsettings reset org.gnome.desktop.interface cursor-theme
    gsettings reset org.gnome.desktop.interface font-name
    gsettings reset org.gnome.desktop.interface color-scheme
    gsettings reset org.gnome.desktop.wm.preferences theme
    gsettings reset org.gnome.desktop.wm.preferences button-layout
    gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.shell.extensions.user-theme$' \
        && gsettings reset org.gnome.shell.extensions.user-theme name || true
    # Remove installed theme/icon/cursor dirs (user-scope only; system dirs untouched)
    rm -rf "$HOME/.themes/WhiteSur"*
    rm -rf "$HOME/.local/share/themes/WhiteSur"*
    rm -rf "$HOME/.icons/WhiteSur"*
    rm -rf "$HOME/.local/share/icons/WhiteSur"*
    ok "Reverted. Log out + back in to fully clear the GNOME Shell theme."
}

post_relogin() {
    log "Enabling extensions and applying post-relogin settings"
    gnome-extensions enable "$EXT_USER_THEMES"   || warn "user-themes still unavailable — log out + back in first"
    gnome-extensions enable "$EXT_DASH_TO_DOCK"  || warn "dash-to-dock still unavailable — log out + back in first"
    gnome-extensions enable "$EXT_BLUR_MY_SHELL" || warn "blur-my-shell still unavailable — log out + back in first"
    install_mac_hover_extension
    gnome-extensions enable "$EXT_MAC_HOVER"     || warn "macos-fullscreen-hover still unavailable — log out + back in first"
    install_panel_extensions
    gnome-extensions enable "$EXT_JUST_PERFECTION" || warn "just-perfection still unavailable — log out + back in first"
    configure_just_perfection
    # Disable Unite if a previous version of this script installed it
    # (we no longer want it — see install_shallow_headerbar_css).
    gnome-extensions disable unite@hardpixel.eu 2>/dev/null || true
    # ubuntu-dock conflicts with dash-to-dock; disable it so DTD takes over.
    gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null || true
    apply_gsettings
    configure_dash_to_dock || true
    install_shallow_headerbar_css
    ok "Post-relogin step done."
}

main() {
    refuse_root
    require_gnome
    mkdir -p "$WORK_DIR"

    case "${1:-}" in
        --uninstall) uninstall; exit 0 ;;
        --post-relogin) post_relogin; exit 0 ;;
    esac

    local skip_ext=0
    [[ "${1:-}" == "--skip-extensions" ]] && skip_ext=1

    ensure_apt_packages
    install_sf_pro_fonts
    install_gtk_theme
    install_icons
    install_cursors
    install_wallpapers
    install_plymouth_theme
    install_grub_theme
    (( skip_ext == 0 )) && install_extensions
    apply_gsettings
    configure_dash_to_dock || true
    install_shallow_headerbar_css
    install_mac_hover_extension
    install_panel_extensions
    configure_just_perfection

    cat <<EOF

$(ok "Setup complete.")

Next steps:
  1. Log out, then log back in (Wayland sessions require this for the
     GNOME Shell theme + extensions to take effect).
  2. Run the post-relogin step to enable extensions, disable ubuntu-dock,
     and apply Dash-to-Dock settings:
         bash $0 --post-relogin
  3. Open 'Tweaks' -> Appearance -> Shell theme: pick "$THEME_NAME".
  4. Set a wallpaper from ~/.local/share/backgrounds/.

To revert:
    bash $0 --uninstall
EOF
}

main "$@"
