#!/bin/bash

set -eo pipefail

# Colors for output
BLACK='\033[0;30m'
WHITE='\033[0;97m'
GRAY='\033[0;90m'
DIM='\033[2m'
BOLD='\033[1m'

PRIMARY='\033[0;97m'
SECONDARY='\033[0;90m'
ACCENT='\033[2;37m'
SUCCESS='\033[0;97m'
ERROR='\033[0;90m'
NC='\033[0m' # No Color

# Check for Linux
if [ "$(uname)" != "Linux" ]; then
    printf "${SECONDARY}▸${NC} Error: This installer only supports Linux systems\n"
    exit 1
fi

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf "${SECONDARY}▸${NC} Missing required command: %s\n" "$1"
        exit 1
    fi
}

require_any_command() {
    local cmd
    for cmd in "$@"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            return 0
        fi
    done

    printf "${SECONDARY}▸${NC} Missing required command (need one of): %s\n" "$*"
    exit 1
}

check_prerequisites() {
    require_command grep
    require_command sed
    require_command tar
    require_command tr
    require_command sort
    require_command mktemp
    require_command find
    require_any_command curl wget
}

check_prerequisites

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
TD_BASE_DIR="$HOME/.local/share/touchdesigner-linux"
RUNNER_DIR="$TD_BASE_DIR/runner"
WINE_PREFIX="$TD_BASE_DIR/prefix"
WINETRICKS_BIN="$TD_BASE_DIR/winetricks"
LOG_DIR="$TD_BASE_DIR/logs"
DOWNLOAD_DIR="$HOME/Downloads"
DESKTOP_DIR="$HOME/Desktop"
APPLICATIONS_DIR="$HOME/.local/share/applications"
LAUNCHER_DIR="$HOME/.local/bin"
LAUNCHER_PATH="$LAUNCHER_DIR/launch-touchdesigner.sh"

SODA_URL="https://github.com/bottlesdevs/wine/releases/download/soda-9.0-1/soda-9.0-1-x86_64.tar.xz"
DXVK_VERSION="2.4"
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/dxvk-${DXVK_VERSION}.tar.gz"
REPO_ASSETS_BASE_URL="${REPO_ASSETS_BASE_URL:-https://raw.githubusercontent.com/isw3d/TouchDesigner-Linux/main/Assets}"
SODA_SHA256="${SODA_SHA256:-}"
DXVK_SHA256="${DXVK_SHA256:-}"

# Get terminal width for horizontal rules
TERMINAL_WIDTH=$(tput cols 2>/dev/null)
TERMINAL_WIDTH=${TERMINAL_WIDTH:-60}

# Read prompts from stdin in normal mode, or from /dev/tty when piped (e.g. curl | bash).
if [ -t 0 ]; then
    INTERACTIVE_INPUT="/dev/stdin"
elif [ -r /dev/tty ]; then
    INTERACTIVE_INPUT="/dev/tty"
else
    INTERACTIVE_INPUT=""
fi

# Configuration variables
FAST_MODE=${FAST_MODE:-false}
NON_INTERACTIVE=${NON_INTERACTIVE:-false}
ALLOW_HEADLESS_INSTALL=${ALLOW_HEADLESS_INSTALL:-false}
INSTALL_CHOICE=${INSTALL_CHOICE:-1}
TD_VERSION=${TD_VERSION:-latest}
FORCE_UNINSTALL=${FORCE_UNINSTALL:-false}
DEBUG=${DEBUG:-false}
TRACE=${TRACE:-false}
ENABLE_DXVK=${ENABLE_DXVK:-Y}
CREATE_SHORTCUT=${CREATE_SHORTCUT:-N}
ASSOC_FILES=${ASSOC_FILES:-N}
WINE_DLL_OVERRIDES="mscoree="
USE_NVIDIA_DGPU=${USE_NVIDIA_DGPU:-N}
TD_ICON_PATH="touchdesigner"
DEBUG_LOG_FILE=""
OPTIONAL_FONT_FIX_LOCATIONS=""

if [ "$NON_INTERACTIVE" = true ]; then
    [ "$CREATE_SHORTCUT" = "N" ] && CREATE_SHORTCUT="Y"
    [ "$ASSOC_FILES" = "N" ] && ASSOC_FILES="Y"
fi

# Utility functions for Iswad aesthetic

print_hr() {
    local hr=$(printf '%.0s─' $(seq 1 "$TERMINAL_WIDTH"))
    printf "${DIM}%s${NC}\n" "$hr"
}

print_banner() {
    [ -t 1 ] && clear
    print_hr
    printf "${BOLD}${PRIMARY}TouchDesigner Linux installer${NC}\n"
    printf "${SECONDARY}By Iswad${NC}\n"
    print_hr
}

print_container() {
    local title="$1"
    local content="$2"
    printf " ${DIM}╔═══════════════════════════════════╗${NC}\n"
    printf " ${DIM}║${NC} %-33s ${DIM}║${NC}\n" "$title: $content"
    printf " ${DIM}╚═══════════════════════════════════╝${NC}\n"
}

print_list_item() {
    local label="$1"
    local text="$2"
    printf "  ${DIM}[${NC}${PRIMARY}${BOLD}%-7s${NC}${DIM}]${NC}  %s\n" "$label" "$text"
}

print_footer() {
    printf "\n"
    print_hr
    printf "Press ${PRIMARY}[Enter]${NC} to start, ${SECONDARY}[Ctrl+C]${NC} to quit\n"
}

print_success() {
    printf "${PRIMARY}▸${NC} %s\n" "$1"
}

print_error() {
    printf "${SECONDARY}▸${NC} %s\n" "$1"
}

print_info() {
    printf "${DIM}→${NC} %s\n" "$1"
}

print_warning() {
    printf "${DIM}•${NC} %s\n" "$1"
}

prompt_yes_no() {
    local prompt="$1"
    local default_choice="$2"

    while true; do
        if [ "$default_choice" = "Y" ]; then
            printf "%s [Y/n]: " "$prompt" >&2
        else
            printf "%s [y/N]: " "$prompt" >&2
        fi

        local answer
        if ! IFS= read -r answer <"$INTERACTIVE_INPUT"; then
            answer=""
        fi

        answer=$(printf "%s" "$answer" | tr -d '[:space:]')

        if [ -z "$answer" ]; then
            PROMPT_YES_NO_RESULT="$default_choice"
            return 0
        fi

        case "$answer" in
            y|Y|yes|YES)
                PROMPT_YES_NO_RESULT="Y"
                return 0
                ;;
            n|N|no|NO)
                PROMPT_YES_NO_RESULT="N"
                return 0
                ;;
            *)
                printf "${DIM}•${NC} Please answer y or n\n" >&2
                ;;
        esac
    done
}

ensure_interactive_input() {
    if [ "$NON_INTERACTIVE" = true ]; then
        return
    fi

    if [ -n "$INTERACTIVE_INPUT" ]; then
        return
    fi

    print_error "No interactive terminal detected for prompts"
    print_info "Run this installer in a terminal session so it can ask for input."
    exit 1
}

check_network_access() {
    local url="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSI --connect-timeout 5 --max-time 10 "$url" >/dev/null 2>&1 && return 0
    elif command -v wget >/dev/null 2>&1; then
        wget -q --spider --timeout=10 "$url" >/dev/null 2>&1 && return 0
    fi

    print_warning "Network check failed for $url (continuing anyway)"
    return 1
}

verify_checksum() {
    local file_path="$1"
    local expected_hash="$2"
    local label="$3"

    if [ -z "$expected_hash" ]; then
        print_warning "No checksum configured for $label (skipping verification)"
        return 0
    fi

    if ! command -v sha256sum >/dev/null 2>&1; then
        print_warning "sha256sum not found, cannot verify $label"
        return 0
    fi

    if printf "%s  %s\n" "$expected_hash" "$file_path" | sha256sum -c - >/dev/null 2>&1; then
        print_success "$label checksum verified"
        return 0
    fi

    print_error "$label checksum verification failed"
    return 1
}

safe_rm_rf() {
    local target="$1"

    if [ -z "$target" ] || [ "$target" = "/" ]; then
        print_error "Refusing to delete unsafe directory: '$target'"
        exit 1
    fi

    rm -rf -- "$target"
}

setup_debug_mode() {
    if [ "$DEBUG" != true ] && [ "$TRACE" != true ]; then
        return
    fi

    mkdir -p "$LOG_DIR"
    DEBUG_LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

    # Mirror all output to a persistent log file for issue reports.
    exec > >(tee -a "$DEBUG_LOG_FILE") 2>&1

    print_warning "Debug logging enabled"
    print_info "Debug log: $DEBUG_LOG_FILE"

    if [ "$TRACE" = true ]; then
        set -x
    fi
}

setup_debug_mode

add_optional_font_fix_location() {
    local location="$1"

    [ -n "$location" ] || return
    case "\n$OPTIONAL_FONT_FIX_LOCATIONS\n" in
        *"\n$location\n"*)
            return
            ;;
    esac

    if [ -n "$OPTIONAL_FONT_FIX_LOCATIONS" ]; then
        OPTIONAL_FONT_FIX_LOCATIONS="$OPTIONAL_FONT_FIX_LOCATIONS
$location"
    else
        OPTIONAL_FONT_FIX_LOCATIONS="$location"
    fi
}

require_graphical_session() {
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        return
    fi

    if [ "$ALLOW_HEADLESS_INSTALL" = true ]; then
        print_warning "No graphical session detected"
        print_info "Continuing in headless preparation mode (GUI-only steps will be skipped)."
        return 1
    fi

    print_error "No graphical session detected"
    print_info "Run this installer from a terminal inside your desktop session (not plain TTY/SSH)."
    print_info "Expected DISPLAY or WAYLAND_DISPLAY to be set."
    exit 1
}

run_and_tail() {
    local lines="$1"
    shift

    local log_file
    log_file=$(mktemp)

    if "$@" >"$log_file" 2>&1; then
        tail -n "$lines" "$log_file"
        rm -f "$log_file"
        return 0
    fi

    tail -n "$lines" "$log_file"
    rm -f "$log_file"
    return 1
}

apt_has_install_candidate() {
    local pkg="$1"
    local candidate

    candidate=$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
    [ -n "$candidate" ] && [ "$candidate" != "(none)" ]
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERACTIVE MENU
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_main_menu() {
    ensure_interactive_input

    if [ "$NON_INTERACTIVE" = true ]; then
        choice=$(printf "%s" "$INSTALL_CHOICE" | tr -d '[:space:]')
        print_info "Non-interactive mode enabled (INSTALL_CHOICE=$choice)"
        return
    fi

    detect_package_manager
    print_banner

    printf "\n${BOLD}${DIM}Environment check${NC}\n\n"

    # System info container
    OS_NAME=$(source /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" 2>/dev/null || echo "Unknown")
    ARCH_NAME=$(uname -m)
    print_container "System" "$OS_NAME / $ARCH_NAME"

    # Compatibility check
    local compat_ok=true
    if [ "$ARCH_NAME" != "x86_64" ]; then
        compat_ok=false
    fi
    if [ "$PKG_MANAGER" = "unknown" ]; then
        compat_ok=false
    fi

    if [ "$compat_ok" = true ]; then
        printf "  ${PRIMARY}▸ Your Linux is supported${NC}\n\n"
    else
        printf "  ${SECONDARY}▸ Your Linux is not supported${NC}\n"
        if [ "$ARCH_NAME" != "x86_64" ]; then
            printf "  ${DIM}  Architecture %s is not supported (x86_64 required)${NC}\n" "$ARCH_NAME"
        fi
        if [ "$PKG_MANAGER" = "unknown" ]; then
            printf "  ${DIM}  No supported package manager found (apt/dnf/pacman/zypper)${NC}\n"
        fi
        printf "\n"
    fi

    # What you get list
    printf "\n${BOLD}${PRIMARY}WHAT YOU GET:${NC}\n\n"
    print_list_item "Runner" "Soda Wine 9.0-1 (standalone, no Bottles)"
    print_list_item "GPU" "DXVK $DXVK_VERSION (DirectX → Vulkan)"
    print_list_item "Font" "All Windows fonts (allfonts)"
    print_list_item "App" "Latest TouchDesigner version installation"

    # Installation options
    printf "\n${PRIMARY}INSTALLATION OPTIONS :${NC}\n\n"
    printf "  1  Full install\n"
    printf "${ACCENT}      • Run TouchDesigner on Linux without Bottles.${NC}\n"
    printf "${ACCENT}      • Auto-configure Wine and required Windows components.${NC}\n"
    printf "${ACCENT}      • Install DXVK for better graphics performance.${NC}\n"
    printf "\n"
    printf "${ACCENT}      -> Already installed? Re-run safely ! Completed steps will be skipped.${NC}\n"
    printf "\n"
    printf "  2  Uninstall\n"
    printf "${ACCENT}      • Removes the Wine prefix, runner, launcher, and all TouchDesigner data.${NC}\n"
    printf "\n"
    printf "  0  Exit\n"
    printf "${ACCENT}      • Quit this script without making changes.${NC}\n\n"

    printf "Select option [1]: "
    if ! IFS= read -r choice <"$INTERACTIVE_INPUT"; then
        choice=""
    fi
    choice=${choice:-1}
    choice=$(printf "%s" "$choice" | tr -d '[:space:]')
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DETECTION & INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

detect_package_manager() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    local os_id="${ID,,}"
    local os_id_like="${ID_LIKE,,}"

    case "$os_id" in
        arch)
            PKG_MANAGER="pacman"; PKG_DISTRO="Arch Linux";
            ;;
        manjaro)
            PKG_MANAGER="pacman"; PKG_DISTRO="Manjaro";
            ;;
        endeavouros)
            PKG_MANAGER="pacman"; PKG_DISTRO="EndeavourOS";
            ;;
        garuda|garudalinux)
            PKG_MANAGER="pacman"; PKG_DISTRO="Garuda Linux";
            ;;
        artix)
            PKG_MANAGER="pacman"; PKG_DISTRO="Artix Linux";
            ;;
        rebornos)
            PKG_MANAGER="pacman"; PKG_DISTRO="RebornOS";
            ;;
        archcraft)
            PKG_MANAGER="pacman"; PKG_DISTRO="Archcraft";
            ;;
        cachyos)
            PKG_MANAGER="pacman"; PKG_DISTRO="CachyOS";
            ;;
        ubuntu)
            PKG_MANAGER="apt"; PKG_DISTRO="Ubuntu";
            ;;
        linuxmint)
            PKG_MANAGER="apt"; PKG_DISTRO="Linux Mint";
            ;;
        pop|pop_os|pop_os)
            PKG_MANAGER="apt"; PKG_DISTRO="Pop!_OS";
            ;;
        debian)
            PKG_MANAGER="apt"; PKG_DISTRO="Debian";
            ;;
        fedora)
            PKG_MANAGER="dnf"; PKG_DISTRO="Fedora";
            ;;
        rocky|rocky-linux)
            PKG_MANAGER="dnf"; PKG_DISTRO="Rocky Linux";
            ;;
        almalinux|alma)
            PKG_MANAGER="dnf"; PKG_DISTRO="AlmaLinux";
            ;;
        centos)
            PKG_MANAGER="dnf"; PKG_DISTRO="CentOS";
            ;;
        opensuse*|suse*)
            PKG_MANAGER="zypper"; PKG_DISTRO="openSUSE/SUSE";
            ;;
        zorin)
            PKG_MANAGER="apt"; PKG_DISTRO="Zorin OS";
            ;;
        elementary)
            PKG_MANAGER="apt"; PKG_DISTRO="elementary OS";
            ;;
        neon)
            PKG_MANAGER="apt"; PKG_DISTRO="KDE Neon";
            ;;
        kali)
            PKG_MANAGER="apt"; PKG_DISTRO="Kali Linux";
            ;;
        parrot)
            PKG_MANAGER="apt"; PKG_DISTRO="Parrot OS";
            ;;
        mx)
            PKG_MANAGER="apt"; PKG_DISTRO="MX Linux";
            ;;
        lmde)
            PKG_MANAGER="apt"; PKG_DISTRO="Linux Mint Debian Edition";
            ;;
        *)
            case "$os_id_like" in
                *arch*)
                    PKG_MANAGER="pacman"; PKG_DISTRO="Arch-based Linux";
                    ;;
                *ubuntu*|*debian*)
                    PKG_MANAGER="apt"; PKG_DISTRO="Ubuntu/Debian-based Linux";
                    ;;
                *fedora*|*rhel*)
                    PKG_MANAGER="dnf"; PKG_DISTRO="Fedora/RHEL-based Linux";
                    ;;
                *suse*)
                    PKG_MANAGER="zypper"; PKG_DISTRO="SUSE-based Linux";
                    ;;
                *)
                    if command -v pacman >/dev/null 2>&1; then
                        PKG_MANAGER="pacman"; PKG_DISTRO="Pacman-based Linux";
                    elif command -v dnf >/dev/null 2>&1; then
                        PKG_MANAGER="dnf"; PKG_DISTRO="DNF-based Linux";
                    elif command -v apt-get >/dev/null 2>&1; then
                        PKG_MANAGER="apt"; PKG_DISTRO="APT-based Linux";
                    elif command -v zypper >/dev/null 2>&1; then
                        PKG_MANAGER="zypper"; PKG_DISTRO="openSUSE/SUSE";
                    else
                        PKG_MANAGER="unknown"; PKG_DISTRO="Unknown Linux";
                    fi
                    ;;
            esac
            ;;
    esac
}

install_packages() {
    case "$PKG_MANAGER" in
        pacman)
            print_info "Enabling multilib repository if needed..."
            if grep -q "^#\[multilib\]" /etc/pacman.conf; then
                sudo sed -i '/^#\[multilib\]/,+1 {
                    s/^#\[multilib\]/[multilib]/
                    s/^#Include/Include/
                }' /etc/pacman.conf 2>/dev/null || true
            fi

            print_info "Installing required packages..."
            local pkg_log
            pkg_log=$(mktemp)
            if ! sudo pacman -S --needed --noconfirm \
                curl wget tar xz cabextract unzip p7zip \
                mesa-utils \
                vulkan-tools vulkan-icd-loader lib32-vulkan-icd-loader \
                lib32-glib2 lib32-gcc-libs lib32-libx11 libx11 \
                xorg-xwayland >"$pkg_log" 2>&1; then
                tail -n 10 "$pkg_log"
                rm -f "$pkg_log"
                print_error "Failed to install packages. Try: sudo pacman -Syu"
                exit 1
            fi
            rm -f "$pkg_log"
            ;;
        apt)
            print_info "Enabling 32-bit architecture..."
            sudo dpkg --add-architecture i386 >/dev/null 2>&1 || true

            print_info "Refreshing apt package index..."
            if ! run_and_tail 5 sudo apt-get update; then
                print_error "Failed to refresh apt package index"
                print_info "Try: sudo apt-get update"
                exit 1
            fi

            local asound_pkg=""
            local asound_pkg_i386=""
            if apt_has_install_candidate "libasound2"; then
                asound_pkg="libasound2"
            elif apt_has_install_candidate "libasound2t64"; then
                asound_pkg="libasound2t64"
            fi

            if [ -n "$asound_pkg" ] && apt_has_install_candidate "${asound_pkg}:i386"; then
                asound_pkg_i386="${asound_pkg}:i386"
            fi

            if [ -z "$asound_pkg" ]; then
                print_warning "Could not resolve libasound package name (continuing without explicit audio runtime package)"
            fi

            local -a apt_packages=(
                curl wget tar xz-utils cabextract unzip p7zip-full
                libvulkan1 libvulkan1:i386 vulkan-tools
                libglib2.0-0 libglib2.0-0:i386
                libx11-6 libx11-6:i386
                libxext6 libxext6:i386
                libxrender1 libxrender1:i386
                libxrandr2 libxrandr2:i386
                libxi6 libxi6:i386
                libxcursor1 libxcursor1:i386
                libxfixes3 libxfixes3:i386
                libxinerama1 libxinerama1:i386
                libxxf86vm1 libxxf86vm1:i386
                libgl1 libgl1:i386
                libegl1 libegl1:i386
                libc6 libc6:i386
                libunwind8 libunwind8:i386
                libgcc-s1 libgcc-s1:i386
                libstdc++6 libstdc++6:i386
                mesa-utils xwayland
            )

            if [ -n "$asound_pkg" ]; then
                apt_packages+=("$asound_pkg")
            fi
            if [ -n "$asound_pkg_i386" ]; then
                apt_packages+=("$asound_pkg_i386")
            fi

            if ! run_and_tail 5 sudo apt-get install -y "${apt_packages[@]}"; then
                print_error "Failed to install required packages"
                print_info "Try: sudo apt-get update && sudo apt-get upgrade"
                exit 1
            fi
            ;;
        dnf)
            print_info "Enabling RPM Fusion free repository if needed..."
            local fedora_ver
            fedora_ver=$(rpm -E %fedora 2>/dev/null)
            if [[ "$fedora_ver" =~ ^[0-9]+$ ]]; then
                sudo dnf install -y \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm" \
                    >/dev/null 2>&1 || true
            fi

            print_info "Installing required packages..."
            if ! run_and_tail 5 sudo dnf install -y \
                curl wget tar xz cabextract unzip p7zip \
                vulkan-loader vulkan-loader.i686 mesa-vulkan-drivers vulkan-tools \
                mesa-demos xorg-x11-server-Xwayland \
                libunwind libunwind.i686 \
                glibc glibc.i686 libgcc libgcc.i686 libstdc++ libstdc++.i686 \
                gnutls gnutls.i686 \
                freetype freetype.i686 fontconfig fontconfig.i686 \
                alsa-lib alsa-lib.i686 \
                libX11 libX11.i686 libXext libXext.i686 \
                libXcomposite libXcomposite.i686 \
                libXrender libXrender.i686 libXrandr libXrandr.i686 \
                libXi libXi.i686 libXcursor libXcursor.i686 \
                libXfixes libXfixes.i686 libXinerama libXinerama.i686 \
                libXxf86vm libXxf86vm.i686 \
                mesa-libGL mesa-libGL.i686 mesa-libGLU mesa-libGLU.i686 mesa-libEGL mesa-libEGL.i686 \
                glib2 glib2.i686 \
                mesa-vulkan-drivers.i686; then
                print_error "Failed to install required packages"
                print_info "Try: sudo dnf upgrade --refresh"
                exit 1
            fi
            ;;
        zypper)
            print_info "Installing required packages..."
            if ! run_and_tail 5 sudo zypper install -y \
                curl wget tar xz cabextract unzip p7zip \
                Mesa-demo-x \
                libvulkan1 libvulkan1-32bit vulkan-tools \
                libglib-2_0-0 libglib-2_0-0-32bit \
                libX11-6 libX11-6-32bit; then
                print_error "Failed to install required packages"
                print_info "Try: sudo zypper refresh && sudo zypper update"
                exit 1
            fi
            ;;
        *)
            print_error "Distribution not automatically supported"
            exit 1
            ;;
    esac

    print_success "System packages installed"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WINE RUNNER SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

download_soda_runner() {
    if [ -f "$RUNNER_DIR/bin/wine64" ]; then
        print_success "Soda Wine runner already installed"
        return
    fi

    print_info "Downloading Soda Wine 9.0-1 runner (~300MB)..."
    local tarball="$TD_BASE_DIR/soda-runner.tar.xz"
    mkdir -p "$TD_BASE_DIR"
    check_network_access "$SODA_URL" || true

    wget --show-progress -O "$tarball" "$SODA_URL" || {
        print_error "Failed to download Soda Wine runner"
        rm -f "$tarball"
        exit 1
    }

    verify_checksum "$tarball" "$SODA_SHA256" "Soda Wine runner" || {
        rm -f "$tarball"
        exit 1
    }

    print_info "Extracting Soda Wine runner..."
    mkdir -p "$RUNNER_DIR"
    tar -xJf "$tarball" -C "$RUNNER_DIR" --strip-components=1
    rm -f "$tarball"

    if [ ! -f "$RUNNER_DIR/bin/wine64" ]; then
        print_error "Wine runner extraction failed: bin/wine64 not found"
        print_info "Contents of $RUNNER_DIR:"
        ls -la "$RUNNER_DIR" 2>/dev/null || true
        exit 1
    fi

    chmod +x "$RUNNER_DIR/bin/wine" "$RUNNER_DIR/bin/wine64" 2>/dev/null || true
    print_success "Soda Wine runner installed"
}

setup_wine_prefix() {
    if [ -d "$WINE_PREFIX/drive_c" ]; then
        if WINEPREFIX="$WINE_PREFIX" \
            WINEDLLOVERRIDES="$WINE_DLL_OVERRIDES" \
            PATH="$RUNNER_DIR/bin:$PATH" \
            "$RUNNER_DIR/bin/wine64" cmd /c exit >/dev/null 2>&1; then
            print_success "Wine prefix already initialized"
            return
        fi

        print_warning "Existing Wine prefix looks broken, recreating it..."
        WINEPREFIX="$WINE_PREFIX" PATH="$RUNNER_DIR/bin:$PATH" \
            "$RUNNER_DIR/bin/wineserver" -k >/dev/null 2>&1 || true
        safe_rm_rf "$WINE_PREFIX"
    fi

    if ! require_graphical_session; then
        print_warning "Skipping Wine prefix initialization (requires graphical session)"
        return
    fi

    print_info "Initializing Wine prefix (win64)..."
    mkdir -p "$WINE_PREFIX"

    local wineboot_log
    wineboot_log=$(mktemp)

    if ! WINEPREFIX="$WINE_PREFIX" \
        WINEARCH=win64 \
        WINEDLLOVERRIDES="$WINE_DLL_OVERRIDES" \
        PATH="$RUNNER_DIR/bin:$PATH" \
            "$RUNNER_DIR/bin/wineboot" --init >"$wineboot_log" 2>&1; then
        tail -n 20 "$wineboot_log" || true

        if grep -qiE 'libunwind\.so\.8|could not load ntdll\.so' "$wineboot_log"; then
            print_error "Wine runtime dependency issue detected (missing libunwind/ntdll runtime)"
            print_info "On Fedora, install missing runtime libs and retry:"
            print_info "sudo dnf install -y libunwind libunwind.i686 glibc glibc.i686 libgcc libgcc.i686 libstdc++ libstdc++.i686 gnutls gnutls.i686 vulkan-loader vulkan-loader.i686"
        fi

        if grep -qiE 'could not load kernel32\.dll|status c0000135' "$wineboot_log"; then
            print_error "Wine runtime dependency issue detected (kernel32.dll load failure)"
            if [ "$PKG_MANAGER" = "dnf" ]; then
                print_info "On Fedora, install missing runtime libs and retry:"
                print_info "sudo dnf install -y libunwind libunwind.i686 glibc glibc.i686 libgcc libgcc.i686 libstdc++ libstdc++.i686 gnutls gnutls.i686 vulkan-loader vulkan-loader.i686 xorg-x11-server-Xwayland"
            else
                print_info "On Ubuntu/Debian, install missing runtime libs and retry:"
                print_info "sudo dpkg --add-architecture i386 && sudo apt-get update"
                print_info "sudo apt-get install -y libc6:i386 libgcc-s1:i386 libstdc++6:i386 libx11-6:i386 libxrandr2:i386 libgl1:i386 xwayland"
            fi
        fi

        if grep -qiE 'xrandr14_get_adapters|nodrv_CreateWindow|No GPU vendor found|Failed to create hwnd' "$wineboot_log"; then
            print_warning "Display/GPU bridge issue detected while creating the Wine prefix"
            print_info "If you are on Wayland, ensure Xwayland is installed and relogin."
        fi

        rm -f "$wineboot_log"
        print_error "Wine prefix initialization failed"
        exit 1
    fi

    rm -f "$wineboot_log"

    sleep 2
    WINEPREFIX="$WINE_PREFIX" PATH="$RUNNER_DIR/bin:$PATH" \
        "$RUNNER_DIR/bin/wineserver" -k 2>/dev/null || true

    if [ ! -d "$WINE_PREFIX/drive_c" ]; then
        print_error "Wine prefix initialization failed"
        exit 1
    fi

    print_success "Wine prefix initialized"
}

download_winetricks() {
    if [ -f "$WINETRICKS_BIN" ] && [ -x "$WINETRICKS_BIN" ]; then
        print_success "Winetricks already available"
        return
    fi

    print_info "Downloading winetricks..."
    mkdir -p "$TD_BASE_DIR"
    wget -O "$WINETRICKS_BIN" \
        "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" || {
        print_error "Failed to download winetricks"
        exit 1
    }
    chmod +x "$WINETRICKS_BIN"
    print_success "Winetricks downloaded"
}

install_dxvk() {
    if [[ "$ENABLE_DXVK" =~ ^[Nn]$ ]]; then
        return
    fi

    local sys32="$WINE_PREFIX/drive_c/windows/system32"
    if [ -f "$sys32/d3d11.dll" ] && file "$sys32/d3d11.dll" 2>/dev/null | grep -qi "PE32"; then
        print_success "DXVK already installed"
        return
    fi

    print_info "Downloading DXVK $DXVK_VERSION..."
    local dxvk_tarball="$TD_BASE_DIR/dxvk.tar.gz"
    check_network_access "$DXVK_URL" || true
    wget -O "$dxvk_tarball" "$DXVK_URL" || {
        print_warning "Failed to download DXVK, skipping"
        rm -f "$dxvk_tarball"
        return
    }

    verify_checksum "$dxvk_tarball" "$DXVK_SHA256" "DXVK archive" || {
        rm -f "$dxvk_tarball"
        return
    }

    local dxvk_dir
    dxvk_dir=$(mktemp -d)
    tar -xzf "$dxvk_tarball" -C "$dxvk_dir" --strip-components=1
    rm -f "$dxvk_tarball"

    print_info "Installing DXVK..."
    PATH="$RUNNER_DIR/bin:$PATH" \
    WINEPREFIX="$WINE_PREFIX" \
    WINE="$RUNNER_DIR/bin/wine64" \
        bash "$dxvk_dir/setup_dxvk.sh" install 2>/dev/null || {
        print_warning "DXVK setup script failed, installing DLLs manually..."
        local syswow64="$WINE_PREFIX/drive_c/windows/syswow64"
        mkdir -p "$sys32" "$syswow64"
        [ -d "$dxvk_dir/x64" ] && cp "$dxvk_dir"/x64/*.dll "$sys32/" 2>/dev/null || true
        [ -d "$dxvk_dir/x32" ] && cp "$dxvk_dir"/x32/*.dll "$syswow64/" 2>/dev/null || true

        for dll in d3d9 d3d10core d3d11 dxgi; do
            WINEPREFIX="$WINE_PREFIX" PATH="$RUNNER_DIR/bin:$PATH" \
                "$RUNNER_DIR/bin/wine64" reg add \
                "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
                /v "$dll" /t REG_SZ /d native /f 2>/dev/null || true
        done
    }

    rm -rf "$dxvk_dir"
    print_success "DXVK installed"
}

install_windows_deps() {
    print_info "Installing Windows dependencies (allfonts, d3dx11_43, vcrun2019)..."
    print_info "This can take several minutes depending on your network and disk speed."

    local wt_log
    wt_log=$(mktemp)

    local wt_start
    wt_start=$(date +%s)

    # Keep the installer visibly alive while winetricks runs in foreground.
    (
        local last_progress=""
        while true; do
            local elapsed
            elapsed=$(( $(date +%s) - wt_start ))

            local progress_line
            progress_line=$(grep -E 'Executing|Downloading|Installing|Using' "$wt_log" 2>/dev/null | tail -n 1)
            if [ -z "$progress_line" ]; then
                progress_line=$(tail -n 1 "$wt_log" 2>/dev/null | tr -d '\r')
            fi

            if [ -n "$progress_line" ] && [ "$progress_line" != "$last_progress" ]; then
                print_info "Winetricks (${elapsed}s): $progress_line"
                last_progress="$progress_line"
            else
                print_info "Winetricks still running... (${elapsed}s)"
            fi

            sleep 12
        done
    ) &
    local heartbeat_pid=$!

    local wt_status=0
    set +e
    PATH="$RUNNER_DIR/bin:$PATH" \
    WINEPREFIX="$WINE_PREFIX" \
    WINEDLLOVERRIDES="$WINE_DLL_OVERRIDES" \
    WINE="$RUNNER_DIR/bin/wine64" \
    WINESERVER="$RUNNER_DIR/bin/wineserver" \
    WINEDEBUG=-all \
        bash "$WINETRICKS_BIN" -q allfonts d3dx11_43 vcrun2019 >"$wt_log" 2>&1
    wt_status=$?
    set -e

    kill "$heartbeat_pid" >/dev/null 2>&1 || true
    wait "$heartbeat_pid" 2>/dev/null || true

    local total_elapsed
    total_elapsed=$(( $(date +%s) - wt_start ))
    print_info "Windows dependencies step completed in ${total_elapsed}s"

    if [ "$wt_status" -ne 0 ]; then
        print_warning "Winetricks exited with status ${wt_status}; checking logs for recoverable issues"
    fi

    # Check for real failures (exclude known harmless patterns)
    local real_errors
    real_errors=$(grep -E 'returned status [^01]|error:|Error:' "$wt_log" \
        | grep -v -E 'returned status 10[0-9]|wineserver:|fixme:|warn:' || true)

    if [ -n "$real_errors" ]; then
        printf "%s\n" "$real_errors"
        print_warning "Winetricks encountered errors (this can be normal for some components)"
    fi

    rm -f "$wt_log"
    print_success "Windows dependencies installed"
}

check_installation_status() {
    printf "\n${BOLD}${DIM}Installation Status Check${NC}\n\n"

    if [ -f "$RUNNER_DIR/bin/wine64" ]; then
        print_success "Soda Wine runner installed"
    else
        print_warning "Soda Wine runner not installed"
        return 1
    fi

    if [ -d "$WINE_PREFIX/drive_c" ]; then
        print_success "Wine prefix initialized"
    else
        print_warning "Wine prefix not initialized"
        return 1
    fi

    if find_touchdesigner_exe >/dev/null; then
        print_success "TouchDesigner executable found"
    else
        print_warning "TouchDesigner executable not found"
        return 1
    fi

    printf "\n${PRIMARY}All installation steps completed!${NC}\n"
    return 0
}

download_touchdesigner() {
    local td_page="https://derivative.ca/download"
    local -a versions=()
    local -a fallback_versions=(
        "2025.32460"
        "2025.30000"
        "2024.10000"
        "2023.12120"
        "2022.33910"
    )
    local selected=""
    local selected_version=""
    local max_versions=10
    local td_html
    td_html=$(mktemp)

    print_info "Fetching available TouchDesigner versions..."
    check_network_access "$td_page" || true
    print_info "Trying Derivative website (curl, timeout 20s)..."
    curl -fsSL \
        --connect-timeout 8 \
        --max-time 20 \
        --retry 1 \
        --retry-delay 1 \
        "$td_page" \
        -o "$td_html" 2>/dev/null || true

    if [ ! -s "$td_html" ]; then
        print_warning "Could not fetch versions with curl"
        print_info "Retrying with wget (timeout 20s)..."
        wget -q \
            --timeout=20 \
            --tries=1 \
            -O "$td_html" "$td_page" 2>/dev/null || true
    fi

    if [ -s "$td_html" ]; then
        mapfile -t versions < <(
            grep -oE 'https://download\.derivative\.ca/TouchDesigner\.[0-9]+\.[0-9]+\.exe' "$td_html" \
                | sed -E 's#^.*/TouchDesigner\.##; s#\.exe$##' \
                | sort -Vu \
                | sort -Vr
        )
    fi

    rm -f "$td_html"

    if [ "${#versions[@]}" -eq 0 ]; then
        print_warning "Could not fetch live version list from Derivative website"
        versions=("${fallback_versions[@]}")
        print_info "Using curated version list fallback"
    else
        print_success "Found ${#versions[@]} available versions"
    fi

    if [ "${#versions[@]}" -gt "$max_versions" ]; then
        versions=("${versions[@]:0:$max_versions}")
    fi

    if [ "$NON_INTERACTIVE" = true ]; then
        if [ -n "$TD_VERSION" ] && [ "$TD_VERSION" != "latest" ]; then
            local found_version=false
            local v
            for v in "${versions[@]}"; do
                if [ "$v" = "$TD_VERSION" ]; then
                    selected_version="$TD_VERSION"
                    found_version=true
                    break
                fi
            done
            if [ "$found_version" = false ]; then
                print_warning "Requested TD_VERSION '$TD_VERSION' not found, using latest available"
            fi
        fi

        if [ -z "$selected_version" ]; then
            selected_version="${versions[0]}"
        fi

        print_info "Non-interactive mode: selected version $selected_version"
    else
        printf "\n${BOLD}${PRIMARY}AVAILABLE TOUCHDESIGNER VERSIONS:${NC}\n"
        printf "${DIM}Use ↑ ↓ to navigate, Enter to select${NC}\n\n"

        local cursor=0
        local count="${#versions[@]}"

        # Draw the list
        _draw_version_list() {
            local i
            for i in "${!versions[@]}"; do
                local label="${versions[$i]}"
                [ "$i" -eq 0 ] && label="${versions[$i]} (Latest stable)"
                if [ "$i" -eq "$cursor" ]; then
                    printf "  ${BOLD}${PRIMARY}▶  %-30s${NC}\n" "$label"
                else
                    printf "  ${DIM}   %-30s${NC}\n" "$label"
                fi
            done
        }

        _draw_version_list

        # Hide cursor while navigating
        tput civis 2>/dev/null || true

        while true; do
            # Read one escape sequence
            local key
            IFS= read -rsn1 key <"$INTERACTIVE_INPUT"
            if [[ "$key" == $'\x1b' ]]; then
                local seq
                IFS= read -rsn2 -t 0.1 seq <"$INTERACTIVE_INPUT"
                key="${key}${seq}"
            fi

            case "$key" in
                $'\x1b[A'|$'\x1b[D')  # Up or Left
                    (( cursor > 0 )) && (( cursor-- )) || true
                    ;;
                $'\x1b[B'|$'\x1b[C')  # Down or Right
                    (( cursor < count - 1 )) && (( cursor++ )) || true
                    ;;
                '')  # Enter
                    break
                    ;;
            esac

            # Redraw: move cursor up by count lines then redraw
            tput cuu "$count" 2>/dev/null || printf "\033[${count}A"
            _draw_version_list
        done

        tput cnorm 2>/dev/null || true
        printf "\n"

        selected_version="${versions[$cursor]}"
    fi

    TD_URL="https://download.derivative.ca/TouchDesigner.$selected_version.exe"
    print_success "Selected version: $selected_version"

    TD_FILENAME=$(basename "$TD_URL")
    mkdir -p "$DOWNLOAD_DIR"

    if [ -f "$DOWNLOAD_DIR/$TD_FILENAME" ]; then
        print_success "File already downloaded"
        TD_FILEPATH="$DOWNLOAD_DIR/$TD_FILENAME"
    else
        print_info "Downloading $TD_FILENAME (≈2GB)..."
        wget --show-progress -P "$DOWNLOAD_DIR" "$TD_URL" || {
            print_error "Download failed"
            exit 1
        }
        print_success "Download completed"
        TD_FILEPATH="$DOWNLOAD_DIR/$TD_FILENAME"
    fi
}

install_touchdesigner() {
    if ! require_graphical_session; then
        print_warning "Skipping TouchDesigner installer launch (requires graphical session)"
        return
    fi

    print_info "Running TouchDesigner installer..."

    local install_log
    install_log=$(mktemp)

    if PATH="$RUNNER_DIR/bin:$PATH" \
       WINEPREFIX="$WINE_PREFIX" \
             WINEDLLOVERRIDES="" \
       WINEDEBUG=-all \
       WINESERVER_DEBUG=0 \
           "$RUNNER_DIR/bin/wine64" "$TD_FILEPATH" >"$install_log" 2>&1; then
        grep -v -E '^[0-9a-f]+:(fixme|warn):|wineserver:' "$install_log" | tail -n 10 || true
        rm -f "$install_log"
        return
    fi

    tail -n 20 "$install_log"

    if grep -qiE 'FreeType font library|freetype\.org' "$install_log"; then
        print_error "Wine runtime font library is missing (FreeType/fontconfig)"
        if [ "$PKG_MANAGER" = "dnf" ]; then
            print_info "On Fedora, run: sudo dnf install -y freetype freetype.i686 fontconfig fontconfig.i686"
        elif [ "$PKG_MANAGER" = "apt" ]; then
            print_info "On Ubuntu/Debian, run: sudo apt-get install -y libfreetype6 libfreetype6:i386 libfontconfig1 libfontconfig1:i386"
        fi
    fi

    if grep -qiE "nodrv_CreateWindow|No GPU vendor found|DISPLAY is set correctly|Failed to create hwnd" "$install_log"; then
        print_error "Installer GUI could not start due to display/GPU access issues"
        print_info "Current env: DISPLAY='${DISPLAY:-unset}', WAYLAND_DISPLAY='${WAYLAND_DISPLAY:-unset}'"
        print_info "Recommended fix on Arch/CachyOS: sudo pacman -S --needed xorg-xwayland vulkan-icd-loader vulkan-tools"
        print_info "Then relogin and retry."
    fi

    rm -f "$install_log"
    exit 1
}

check_graphics() {
    print_info "Checking graphics support..."

    if command -v lspci >/dev/null 2>&1; then
        local gpu_lines
        gpu_lines=$(lspci 2>/dev/null | grep -E 'VGA compatible controller|3D controller|Display controller' || true)
        if [ -n "$gpu_lines" ]; then
            print_info "Detected GPUs (PCI):"
            printf "%s\n" "$gpu_lines"
        fi
    fi

    if command -v nvidia-smi >/dev/null 2>&1; then
        local nvidia_gpus
        nvidia_gpus=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || true)
        if [ -n "$nvidia_gpus" ]; then
            print_info "Detected NVIDIA GPU(s):"
            printf "%s\n" "$nvidia_gpus"
        fi
    fi

    if command -v glxinfo >/dev/null 2>&1; then
        local glx_info
        glx_info=$(glxinfo 2>/dev/null | grep -E "OpenGL vendor string|OpenGL renderer string|OpenGL version string")
        if [ -n "$glx_info" ]; then
            printf "%s\n" "$glx_info"
            if command -v nvidia-smi >/dev/null 2>&1 && ! echo "$glx_info" | grep -qi nvidia; then
                print_warning "OpenGL is currently using a non-NVIDIA GPU"
                print_info "Set USE_NVIDIA_DGPU=Y before launch to force NVIDIA offload on hybrid laptops."
            fi
            if echo "$glx_info" | grep -qi llvmpipe; then
                print_warning "LLVMPipe detected: software rendering may reduce TouchDesigner performance."
            fi
        else
            print_warning "glxinfo did not return OpenGL information."
        fi
    else
        if [ "$PKG_MANAGER" = "dnf" ] && command -v rpm >/dev/null 2>&1 \
            && rpm -q mesa-demos >/dev/null 2>&1; then
            if [ -f /run/.containerenv ] || [ -n "${container:-}" ]; then
                print_warning "glxinfo is not visible in this container environment (mesa-demos is installed)."
                print_info "If Vulkan is detected, this is usually safe to ignore."
            else
                print_warning "mesa-demos is installed but glxinfo command is missing from PATH."
            fi
            return
        fi

        case "$PKG_MANAGER" in
            apt)
                print_warning "glxinfo not installed. Install: sudo apt-get install -y mesa-utils"
                ;;
            dnf)
                print_warning "glxinfo not installed. Install: sudo dnf install -y mesa-demos"
                ;;
            pacman)
                print_warning "glxinfo not installed. Install: sudo pacman -S --needed mesa-utils"
                ;;
            zypper)
                print_warning "glxinfo not installed. Install: sudo zypper install -y Mesa-demo-x"
                ;;
            *)
                print_warning "glxinfo not installed. Install mesa-utils or equivalent to verify OpenGL support."
                ;;
        esac
    fi

    if command -v vulkaninfo >/dev/null 2>&1; then
        if vulkaninfo > /dev/null 2>&1; then
            print_success "Vulkan support detected"
        else
            print_warning "Vulkan support is unavailable or not configured."
        fi
    else
        print_warning "vulkaninfo not installed. Install vulkan-tools to verify Vulkan support."
    fi
}

find_touchdesigner_exe() {
    find "$WINE_PREFIX/drive_c" -type f -iname 'TouchDesigner.exe' 2>/dev/null | head -n 1
}

register_toe_mimetype() {
    local mime_dir="$HOME/.local/share/mime/packages"
    mkdir -p "$mime_dir"

    cat > "$mime_dir/touchdesigner.xml" << XML
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-touchdesigner">
    <comment>TouchDesigner project file</comment>
    <glob pattern="*.toe"/>
  </mime-type>
</mime-info>
XML

    if command -v update-mime-database >/dev/null 2>&1; then
        update-mime-database "$HOME/.local/share/mime" >/dev/null 2>&1 || true
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POST-INSTALLATION FEATURES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_launcher_script() {
    local runner_path="$RUNNER_DIR"
    local prefix_path="$WINE_PREFIX"
    local nvidia_mode="$USE_NVIDIA_DGPU"

    mkdir -p "$LAUNCHER_DIR"

    cat > "$LAUNCHER_PATH" << LAUNCHER
#!/bin/bash
RUNNER_DIR="${runner_path}"
WINE_PREFIX="${prefix_path}"
USE_NVIDIA_DGPU="${nvidia_mode}"

find_touchdesigner_exe() {
    find "\$WINE_PREFIX/drive_c" -type f -iname 'TouchDesigner.exe' 2>/dev/null | head -n 1
}

TOUCHDESIGNER_EXE="\$(find_touchdesigner_exe)"

if [ -z "\$TOUCHDESIGNER_EXE" ]; then
    echo "Error: TouchDesigner.exe not found in Wine prefix."
    exit 1
fi

# On hybrid laptops, optionally offload rendering to NVIDIA dGPU.
if command -v nvidia-smi >/dev/null 2>&1; then
    if [ "\$USE_NVIDIA_DGPU" = "Y" ] || [ "\$USE_NVIDIA_DGPU" = "y" ]; then
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        export DRI_PRIME=1
    fi
fi

# Handle optional .toe file argument
EXTRA_ARGS=()
if [ -n "\$1" ]; then
    INPUT_PATH="\$1"
    # Decode file:// URI if passed by desktop environment
    if [[ "\$INPUT_PATH" == file://* ]]; then
        INPUT_PATH="\${INPUT_PATH#file://}"
        INPUT_PATH="\$(python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))" "\$INPUT_PATH" 2>/dev/null || echo "\$INPUT_PATH")"
    fi
    # Map Linux path to Wine Z: drive
    WINE_PATH="z:\${INPUT_PATH//\//\\\\}"
    EXTRA_ARGS=("\$WINE_PATH")
fi

PATH="\$RUNNER_DIR/bin:\$PATH" \\
WINEPREFIX="\$WINE_PREFIX" \\
    "\$RUNNER_DIR/bin/wine64" "\$TOUCHDESIGNER_EXE" "\${EXTRA_ARGS[@]}" &
LAUNCHER
    chmod +x "$LAUNCHER_PATH"
}

install_optional_font_fix() {
    local src
    local dest="$TD_BASE_DIR/wine_ui_fixes.tox"

    mkdir -p "$TD_BASE_DIR"

    for src in "$SCRIPT_DIR/wine_ui_fixes.tox" "$SCRIPT_DIR/Assets/wine_ui_fixes.tox"; do
        if [ -f "$src" ]; then
            cp -f "$src" "$dest"
            return 0
        fi
    done

    if curl -fsSL --max-time 20 "$REPO_ASSETS_BASE_URL/wine_ui_fixes.tox" -o "$dest" 2>/dev/null; then
        return 0
    fi

    if wget -q -O "$dest" "$REPO_ASSETS_BASE_URL/wine_ui_fixes.tox" 2>/dev/null; then
        return 0
    fi

    rm -f "$dest"
    return 1
}

distribute_optional_font_fix() {
    local src="$TD_BASE_DIR/wine_ui_fixes.tox"
    local host_docs="$HOME/Documents"
    local host_target="$host_docs/TouchDesigner"
    local wine_user_dir="$WINE_PREFIX/drive_c/users/$USER"
    local wine_username="$USER"
    local wine_desktop="$wine_user_dir/Desktop"

    [ -f "$src" ] || return 0
    OPTIONAL_FONT_FIX_LOCATIONS=""
    add_optional_font_fix_location "$src"

    # Host-visible location for easy manual import.
    mkdir -p "$host_target"
    local host_fix_path="$host_target/wine_ui_fixes.tox"
    if cp -f "$src" "$host_fix_path" 2>/dev/null; then
        add_optional_font_fix_location "$host_fix_path"
    fi

    # Wine-visible locations for easy drag-and-drop inside TouchDesigner.
    if [ -d "$WINE_PREFIX/drive_c" ]; then
        if [ ! -d "$wine_user_dir" ]; then
            local detected_user_dir
            detected_user_dir=$(find "$WINE_PREFIX/drive_c/users" -mindepth 1 -maxdepth 1 -type d \
                ! -iname 'Public' ! -iname 'Default' ! -iname 'Default User' \
                2>/dev/null | head -n 1)
            if [ -n "$detected_user_dir" ]; then
                wine_user_dir="$detected_user_dir"
                wine_username="$(basename "$detected_user_dir")"
                wine_desktop="$wine_user_dir/Desktop"
            fi
        fi

        if [ -x "$RUNNER_DIR/bin/wine64" ]; then
            local resolved_desktop=""

            resolved_desktop=$(WINEPREFIX="$WINE_PREFIX" PATH="$RUNNER_DIR/bin:$PATH" \
                "$RUNNER_DIR/bin/wine64" winepath -u "C:\\users\\$wine_username\\Desktop" 2>/dev/null | tr -d '\r')

            if [ -n "$resolved_desktop" ] && [ -d "$resolved_desktop" ]; then
                wine_desktop="$resolved_desktop"
            fi
        fi

        mkdir -p "$wine_desktop"
        local wine_desktop_fix_path="$wine_desktop/wine_ui_fixes.tox"

        if cp -f "$src" "$wine_desktop_fix_path" 2>/dev/null; then
            add_optional_font_fix_location "$wine_desktop_fix_path"
        fi
    fi
}

install_optional_icon() {
    local src
    TD_ICON_PATH="touchdesigner"

    mkdir -p "$TD_BASE_DIR"

    for src in \
        "$SCRIPT_DIR/TouchDesigner.png" \
        "$SCRIPT_DIR/Assets/TouchDesigner.png"; do
        if [ -f "$src" ]; then
            cp -f "$src" "$TD_BASE_DIR/TouchDesigner.png"
            TD_ICON_PATH="$TD_BASE_DIR/TouchDesigner.png"
            return 0
        fi
    done

    if curl -fsSL --max-time 20 "$REPO_ASSETS_BASE_URL/TouchDesigner.png" -o "$TD_BASE_DIR/TouchDesigner.png" 2>/dev/null; then
        TD_ICON_PATH="$TD_BASE_DIR/TouchDesigner.png"
        return 0
    fi

    if wget -q -O "$TD_BASE_DIR/TouchDesigner.png" "$REPO_ASSETS_BASE_URL/TouchDesigner.png" 2>/dev/null; then
        TD_ICON_PATH="$TD_BASE_DIR/TouchDesigner.png"
        return 0
    fi

    for src in \
        "$SCRIPT_DIR/_TouchDesigner.png.ico" \
        "$SCRIPT_DIR/Assets/_TouchDesigner.png.ico"; do
        if [ -f "$src" ]; then
            cp -f "$src" "$TD_BASE_DIR/_TouchDesigner.png.ico"
            TD_ICON_PATH="$TD_BASE_DIR/_TouchDesigner.png.ico"
            return 0
        fi
    done

    if curl -fsSL --max-time 20 "$REPO_ASSETS_BASE_URL/_TouchDesigner.png.ico" -o "$TD_BASE_DIR/_TouchDesigner.png.ico" 2>/dev/null; then
        TD_ICON_PATH="$TD_BASE_DIR/_TouchDesigner.png.ico"
        return 0
    fi

    if wget -q -O "$TD_BASE_DIR/_TouchDesigner.png.ico" "$REPO_ASSETS_BASE_URL/_TouchDesigner.png.ico" 2>/dev/null; then
        TD_ICON_PATH="$TD_BASE_DIR/_TouchDesigner.png.ico"
        return 0
    fi

    rm -f "$TD_BASE_DIR/TouchDesigner.png" "$TD_BASE_DIR/_TouchDesigner.png.ico"
    return 1
}

create_desktop_shortcut() {
    if [[ ! $CREATE_SHORTCUT =~ ^[Yy]$ ]]; then
        return
    fi

    mkdir -p "$DESKTOP_DIR"

    cat > "$DESKTOP_DIR/TouchDesigner.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=TouchDesigner
Comment=Real-time Visual Programming Environment
Exec=$LAUNCHER_PATH
Icon=$TD_ICON_PATH
Terminal=false
Categories=Graphics;Development;
DESKTOP

    trust_desktop_shortcut "$DESKTOP_DIR/TouchDesigner.desktop"
    print_success "Desktop shortcut created"
}

trust_desktop_shortcut() {
    local desktop_file="$1"

    [ -f "$desktop_file" ] || return 0
    chmod +x "$desktop_file" 2>/dev/null || true

    if command -v gio >/dev/null 2>&1; then
        gio set "$desktop_file" metadata::trusted true >/dev/null 2>&1 || true
    fi
}

create_applications_shortcut() {
    if [[ ! $CREATE_SHORTCUT =~ ^[Yy]$ ]]; then
        return
    fi

    mkdir -p "$APPLICATIONS_DIR"

    cat > "$APPLICATIONS_DIR/touchdesigner.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=TouchDesigner
Comment=Real-time Visual Programming Environment
Exec=$LAUNCHER_PATH
Icon=$TD_ICON_PATH
Terminal=false
Categories=Graphics;Development;
DESKTOP

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
    fi

    print_success "Application menu entry created"
}

associate_toe_files() {
    if [[ ! $ASSOC_FILES =~ ^[Yy]$ ]]; then
        return
    fi

    mkdir -p "$APPLICATIONS_DIR"

    cat > "$APPLICATIONS_DIR/touchdesigner-file.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=TouchDesigner (Project File)
Exec=$LAUNCHER_PATH %u
Icon=$TD_ICON_PATH
MimeType=application/x-touchdesigner;
NoDisplay=true
Categories=Graphics;Development;
DESKTOP

    register_toe_mimetype

    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default touchdesigner-file.desktop application/x-touchdesigner 2>/dev/null || true
    fi

    print_success ".toe files associated"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLEANUP & UNINSTALL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

uninstall_touchdesigner() {
    ensure_interactive_input
    print_warning "This will completely remove TouchDesigner and all related files"

    if [ "$NON_INTERACTIVE" = true ]; then
        if [ "$FORCE_UNINSTALL" != true ]; then
            print_error "Refusing uninstall in non-interactive mode without FORCE_UNINSTALL=true"
            return
        fi
        REPLY="Y"
    else
        prompt_yes_no "Are you sure?" "Y"
        REPLY="$PROMPT_YES_NO_RESULT"
    fi

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled"
        return
    fi

    print_info "Removing Wine prefix and runner..."
    if [ -d "$TD_BASE_DIR" ]; then
        safe_rm_rf "$TD_BASE_DIR"
        print_success "Wine prefix and runner removed"
    else
        print_info "Base directory not found (already removed?)"
    fi

    print_info "Removing launcher script..."
    if [ -f "$LAUNCHER_PATH" ]; then
        rm -f "$LAUNCHER_PATH"
        print_success "Launcher script removed"
    fi
    if [ -f "$HOME/launch-touchdesigner.sh" ]; then
        rm -f "$HOME/launch-touchdesigner.sh"
        print_success "Launcher script removed"
    fi

    print_info "Removing desktop shortcut..."
    if [ -f "$DESKTOP_DIR/TouchDesigner.desktop" ]; then
        rm -f "$DESKTOP_DIR/TouchDesigner.desktop"
        print_success "Desktop shortcut removed"
    fi

    print_info "Removing file association..."
    if [ -f "$APPLICATIONS_DIR/touchdesigner.desktop" ]; then
        rm -f "$APPLICATIONS_DIR/touchdesigner.desktop"
        print_success "Application menu entry removed"
    fi
    if [ -f "$APPLICATIONS_DIR/touchdesigner-file.desktop" ]; then
        rm -f "$APPLICATIONS_DIR/touchdesigner-file.desktop"
        print_success "File association removed"
    fi

    local mime_dir="$HOME/.local/share/mime/packages"
    if [ -f "$mime_dir/touchdesigner.xml" ]; then
        rm -f "$mime_dir/touchdesigner.xml"
        if command -v update-mime-database >/dev/null 2>&1; then
            update-mime-database "$HOME/.local/share/mime" >/dev/null 2>&1 || true
        fi
        print_success "MIME type removed"
    fi

    printf "\n${DIM}────────────────────────────────────────────${NC}\n"
    printf "${PRIMARY}Uninstall Complete${NC}\n"
    printf "${PRIMARY}TouchDesigner has been completely removed.${NC}\n"
    printf "${SECONDARY}Iswad${NC}\n"
    printf "${DIM}────────────────────────────────────────────${NC}\n\n"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    show_main_menu

    case $choice in
        1)
            local headless_mode=false
            if [ "$ALLOW_HEADLESS_INSTALL" = true ] && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
                headless_mode=true
            fi

            print_banner
            print_info "Starting TouchDesigner installation..."
            printf "\n"

            # Step 1: System packages
            print_info "Step 1/6: Installing system packages..."
            detect_package_manager
            [[ "$PKG_MANAGER" == "unknown" ]] && { print_error "Unsupported distribution"; exit 1; }
            print_success "Detected: $PKG_DISTRO ($PKG_MANAGER)"
            if ! command -v sudo >/dev/null 2>&1; then
                print_error "sudo is required to install system packages"
                exit 1
            fi
            install_packages
            check_graphics
            [ "$FAST_MODE" != true ] && sleep 0.3

            # Step 2: Soda Wine runner
            if [ ! -f "$RUNNER_DIR/bin/wine64" ]; then
                print_info "Step 2/6: Downloading Soda Wine runner..."
                download_soda_runner
            else
                print_success "Step 2/6: Soda Wine runner already present, skipping..."
            fi
            [ "$FAST_MODE" != true ] && sleep 0.3

            # Step 3: Wine prefix
            if [ ! -d "$WINE_PREFIX/drive_c" ]; then
                print_info "Step 3/6: Initializing Wine prefix..."
                setup_wine_prefix
            else
                print_success "Step 3/6: Wine prefix already initialized, skipping..."
            fi
            [ "$FAST_MODE" != true ] && sleep 0.3

            # Step 4: Windows dependencies
            if [ -d "$WINE_PREFIX/drive_c" ]; then
                print_info "Step 4/6: Installing Windows dependencies..."
                download_winetricks
                install_windows_deps
                install_dxvk
            else
                print_warning "Step 4/6: Skipped (Wine prefix not initialized)"
            fi
            [ "$FAST_MODE" != true ] && sleep 0.3

            # Step 5: Download TouchDesigner
            print_info "Step 5/6: Downloading TouchDesigner..."
            download_touchdesigner
            [ "$FAST_MODE" != true ] && sleep 0.3

            # Step 6: Install TouchDesigner
            if [ -d "$WINE_PREFIX/drive_c" ]; then
                print_info "Step 6/6: Running TouchDesigner installer..."
                install_touchdesigner
            else
                print_warning "Step 6/6: Skipped (requires graphical session)"
            fi

            if find_touchdesigner_exe >/dev/null; then
                # Create launcher
                print_info "Creating launcher script..."
                create_launcher_script
                print_success "Launcher created: ~/.local/bin/launch-touchdesigner.sh"

                install_optional_icon || true
                if [ "$TD_ICON_PATH" != "touchdesigner" ]; then
                    print_info "Icon installed: $TD_ICON_PATH"
                fi
                [ "$FAST_MODE" != true ] && sleep 0.3

                if [ "$NON_INTERACTIVE" = true ]; then
                    print_info "Non-interactive mode: CREATE_SHORTCUT=$CREATE_SHORTCUT"
                else
                    prompt_yes_no "Create desktop shortcut?" "N"
                    CREATE_SHORTCUT="$PROMPT_YES_NO_RESULT"
                fi
                create_desktop_shortcut
                create_applications_shortcut

                if [ "$NON_INTERACTIVE" = true ]; then
                    print_info "Non-interactive mode: ASSOC_FILES=$ASSOC_FILES"
                else
                    prompt_yes_no "Associate .toe files with TouchDesigner?" "N"
                    ASSOC_FILES="$PROMPT_YES_NO_RESULT"
                fi
                associate_toe_files
            else
                print_warning "TouchDesigner is not installed yet; skipping launcher and desktop integration"
            fi

            if install_optional_font_fix; then
                distribute_optional_font_fix
                print_info "Font fix available:"

                while IFS= read -r fix_location; do
                    [ -n "$fix_location" ] || continue
                    print_info "$fix_location"
                done <<< "$OPTIONAL_FONT_FIX_LOCATIONS"

                print_info "Import it in your TouchDesigner project if UI text is missing"
            fi

            printf "\n${DIM}────────────────────────────────────────────${NC}\n"
            if [ "$headless_mode" = true ]; then
                printf "${PRIMARY}Headless Preparation Complete${NC}\n"
                printf "${SECONDARY}Re-run this script from a graphical session to finish installation.${NC}\n"
            else
                printf "${PRIMARY}Installation Complete${NC}\n"
                printf "${SECONDARY}TouchDesigner is ready to use!${NC}\n"
            fi
            printf "\n"
            if find_touchdesigner_exe >/dev/null; then
                print_success "Launch TouchDesigner from the shortcut, or run this command in your terminal:"
                print_info "$LAUNCHER_PATH"
            else
                print_info "When you have a graphical session, re-run the installer and choose Full install."
            fi
            if [ -n "$DEBUG_LOG_FILE" ]; then
                print_info "Debug log saved to: $DEBUG_LOG_FILE"
            fi
            printf "\n"
            printf "${SECONDARY}Iswad${NC}\n"
            printf "${DIM}────────────────────────────────────────────${NC}\n\n"
            ;;
        2)
            uninstall_touchdesigner
            ;;
        0)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

main "$@"