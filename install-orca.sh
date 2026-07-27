#!/usr/bin/env bash
# install-orca.sh
# Install Orca ADE (https://www.onorca.dev/) on Linux and optionally
# start it in headless (serve) mode.
#
# Designed for Docker containers where ports are dynamically mapped
# via run_docker.sh (range 10000-20000, 20 consecutive ports).
#
# Usage:
#   bash ~/.dotfiles/install-orca.sh                        # install only
#   bash ~/.dotfiles/install-orca.sh serve 10.0.0.5:10058   # install + headless on host:port
#   bash ~/.dotfiles/install-orca.sh serve :10058            # localhost:10058
#   bash ~/.dotfiles/install-orca.sh serve 10.0.0.5          # host:6768 (default port)
#   bash ~/.dotfiles/install-orca.sh status                  # show port mapping info

set -euo pipefail

ORCA_DEFAULT_PORT=6768
ORCA_GITHUB="stablyai/orca"

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m[OK]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[X]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- detect container port mapping ----------
detect_mapped_ports() {
    local start end
    if [[ -f /proc/net/tcp ]]; then
        log "Scanning listening ports..."
        # Parse /proc/net/tcp for listening (0A) sockets bound to 0.0.0.0
        local ports=()
        while IFS=' :' read -r _ _ local_addr local_port _ _ state _rest; do
            if [[ "$state" == "0A" && "$local_addr" == "00000000" ]]; then
                ports+=("$((16#$local_port))")
            fi
        done < <(tail -n +2 /proc/net/tcp)

        if (( ${#ports[@]} > 0 )); then
            printf '%s\n' "${ports[@]}" | sort -n
            return 0
        fi
    fi

    # Fallback: check the 10000-20000 range mentioned in run_docker.sh
    log "No 0.0.0.0 listeners found. Docker mapped ports are available externally."
    log "run_docker.sh maps 20 consecutive ports from 10000-20000 range."
    log "Orca default port ($ORCA_DEFAULT_PORT) is outside this range."
    log "Use a port in the mapped range: e.g., bash $0 serve 10005"
    return 1
}

suggest_port() {
    local mapped
    mapped=$(detect_mapped_ports 2>/dev/null) || true

    if [[ -z "$mapped" ]]; then
        warn "Cannot auto-detect mapped ports from inside container."
        warn "Check on host: docker port $(hostname) or docker inspect $(hostname)"
        echo ""
        echo "  Mapped port range (from run_docker.sh): 10000-20000 (20 consecutive)"
        echo "  Orca default port ($ORCA_DEFAULT_PORT) is NOT in this range."
        echo ""
        echo "  Options:"
        echo "    1. Pick a port from your mapped range:"
        echo "       bash $0 serve <PORT>   (e.g., 10005)"
        echo ""
        echo "    2. Recreate container with port $ORCA_DEFAULT_PORT mapped:"
        echo "       Add -p $ORCA_DEFAULT_PORT:$ORCA_DEFAULT_PORT to docker run"
        echo ""
        echo "    3. Use --network host (no port mapping needed):"
        echo "       docker run --network host ..."
        echo ""
    fi
}

# ---------- install ----------
install_orca() {
    if command -v orca &>/dev/null; then
        ok "Orca already installed: $(orca --version 2>/dev/null || echo 'unknown version')"
        return 0
    fi

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) die "Unsupported architecture: $arch" ;;
    esac

    log "Fetching latest Orca release from GitHub..."
    local release_url deb_url deb_file

    # Try to find the .deb asset from latest release
    if command -v curl &>/dev/null; then
        release_url=$(curl -fsSL "https://api.github.com/repos/${ORCA_GITHUB}/releases/latest" \
            | grep -oP '"browser_download_url":\s*"\K[^"]*'"${arch}"'\.deb' \
            | head -1) || true
    fi

    if [[ -z "${release_url:-}" ]]; then
        # Fallback: try common naming patterns
        local tag
        tag=$(curl -fsSL "https://api.github.com/repos/${ORCA_GITHUB}/releases/latest" \
            | grep -oP '"tag_name":\s*"\K[^"]*' | head -1) || true

        if [[ -n "$tag" ]]; then
            local version="${tag#v}"
            # Try multiple naming conventions
            for pattern in \
                "orca_${version}_${arch}.deb" \
                "orca-${version}-${arch}.deb" \
                "orca_${arch}.deb" \
                "Orca_${version}_${arch}.deb"; do
                deb_url="https://github.com/${ORCA_GITHUB}/releases/download/${tag}/${pattern}"
                if curl -fsSL --head "$deb_url" &>/dev/null; then
                    release_url="$deb_url"
                    break
                fi
            done
        fi
    fi

    if [[ -z "${release_url:-}" ]]; then
        warn "Could not auto-detect .deb download URL."
        echo ""
        echo "  Manual install:"
        echo "    1. Visit https://github.com/${ORCA_GITHUB}/releases/latest"
        echo "    2. Download the .deb for ${arch}"
        echo "    3. sudo dpkg -i <file>.deb && sudo apt-get install -f -y"
        echo ""
        die "Auto-install failed. Install manually and re-run."
    fi

    deb_file="/tmp/orca_latest_${arch}.deb"
    log "Downloading: $release_url"
    curl -fsSL -o "$deb_file" "$release_url"

    log "Installing Orca..."
    sudo dpkg -i "$deb_file" || sudo apt-get install -f -y
    rm -f "$deb_file"

    # Binary installs to /opt/Orca/resources/bin/orca-ide
    local orca_bin="/opt/Orca/resources/bin/orca-ide"
    if [[ -x "$orca_bin" ]]; then
        if ! command -v orca &>/dev/null; then
            ln -sf "$orca_bin" /usr/local/bin/orca
        fi
        ok "Orca installed: $(orca --version 2>/dev/null || echo 'done')"
    else
        die "Installation completed but orca binary not found"
    fi
}

# ---------- serve ----------
serve_orca() {
    local addr="${1:-}"

    if [[ -z "$addr" ]]; then
        warn "No address specified."
        echo "Usage: bash $0 serve <host>:<port>"
        echo "       bash $0 serve :<port>          (localhost:<port>)"
        echo "       bash $0 serve <host>            (host:$ORCA_DEFAULT_PORT)"
        exit 1
    fi

    if ! command -v orca &>/dev/null; then
        die "Orca not installed. Run: bash $0"
    fi

    local host port
    if [[ "$addr" == *:* ]]; then
        host="${addr%%:*}"
        port="${addr##*:}"
    else
        host="$addr"
        port=""
    fi
    host="${host:-localhost}"
    port="${port:-$ORCA_DEFAULT_PORT}"

    # Electron refuses to run as root without --no-sandbox
    # Orca checks ORCA_APPIMAGE_NO_SANDBOX to inject --no-sandbox
    if [[ $EUID -eq 0 ]]; then
        export ORCA_APPIMAGE_NO_SANDBOX=1
    fi

    log "Starting Orca headless on $host:$port"
    echo ""
    echo "  Connect from local Orca client:"
    echo "    Open Orca → Settings → Remote Servers → Add Server"
    echo "    Paste the pairing URL printed below"
    echo ""

    exec orca serve --port "$port" --pairing-address "$host"
}

# ---------- main ----------
main() {
    case "${1:-}" in
        serve)
            install_orca
            serve_orca "${2:-}"
            ;;
        status)
            suggest_port
            ;;
        *)
            install_orca
            echo ""
            echo "Next: bash $0 serve <PORT>"
            echo "See:  bash $0 status  (for port mapping help)"
            ;;
    esac
}

main "$@"
