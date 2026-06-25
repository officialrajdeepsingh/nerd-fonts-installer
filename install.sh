#!/usr/bin/env bash
# Nerd Fonts Installer — cross-platform Nerd Font installer
#
# Website: https://github.com/officialrajdeepsingh/nerd-fonts-installer
# License: MIT
#
# This script installs Nerd Fonts on Linux, macOS, and Windows (Cygwin/WSL).
# It supports interactive (menu) and non-interactive (CLI args) modes.
# Download the latest release and always prefer .tar.xz over .zip.

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Version of this installer (matches package.json). Passed via env by cli wrapper,
# falls back to reading package.json directly, then to hardcoded default.
readonly NERD_FONTS_INSTALLER_VERSION="${NERD_FONTS_INSTALLER_VERSION:-$(sed -n 's/.*"version": "\(.*\)".*/\1/p' "$(dirname "$0")/package.json" 2>/dev/null || echo "1.0.2")}"

# Visual prefix prepended to all log messages
readonly LOG_PREFIX="█▓▒░"

# 0 = silent (errors only), 1 = normal (default)
LOG_LEVEL="${LOG_LEVEL:-1}"

# =============================================================================
# LOGGING & OUTPUT
# =============================================================================

setup_colors() {
    USE_COLOR="${USE_COLOR:-auto}"
    CLR_INFO="" CLR_SUCCESS="" CLR_ERROR="" CLR_RESET=""
    if [[ "${USE_COLOR}" == "auto" ]]; then
        [[ -t 1 ]] && USE_COLOR=1 || USE_COLOR=0
    fi
    if (( USE_COLOR )); then
        CLR_INFO="\033[0;36m"      # cyan
        CLR_SUCCESS="\033[0;32m"   # green
        CLR_ERROR="\033[0;31m"     # red
        CLR_RESET="\033[0m"
    fi
}

# shellcheck disable=SC2059
log_info()    { (( LOG_LEVEL >= 1 )) || return 0; local fmt="$1"; shift; printf "${CLR_INFO}%s ${fmt}${CLR_RESET}\n" "${LOG_PREFIX}" "$@"; }
# shellcheck disable=SC2059
log_success() { (( LOG_LEVEL >= 1 )) || return 0; local fmt="$1"; shift; printf "${CLR_SUCCESS}%s ${fmt}${CLR_RESET}\n" "${LOG_PREFIX}" "$@"; }
# shellcheck disable=SC2059
log_error()   { local fmt="$1"; shift; printf "${CLR_ERROR}%s ${fmt}${CLR_RESET}\n" "${LOG_PREFIX}" "$@" >&2; }

quit() {
    log_info "Exiting. Have a nice day"
    exit 0
}

# =============================================================================
# HELPERS
# =============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

to_lower() { printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

# -----------------------------------------------------------------------------
# Archive format detection
# -----------------------------------------------------------------------------

tar_has_xz_support() {
    # BSD tar (macOS/libarchive) has built-in xz support
    tar --version 2>&1 | grep -qiE 'bsd|libarchive' && return 0
    # GNU tar delegates to the xz binary
    command_exists xz
}

# -----------------------------------------------------------------------------
# Tool detection — finds first available tool from a list
# -----------------------------------------------------------------------------

tool_require_first() {
    local out_var_name="$1"
    shift
    local tool_candidate
    for tool_candidate in "$@"; do
        if command_exists "${tool_candidate}"; then
            printf -v "${out_var_name}" "%s" "${tool_candidate}"
            return 0
        fi
    done
    TOOL_MISSING_LIST+=("$(IFS='/'; printf "%s" "$*")")
}

# =============================================================================
# FONT SELECTION — add, remove, resolve, search
# =============================================================================

# Match a font name (case-insensitive) against FONT_LIST_AVAILABLE
font_resolve() {
    local font_query font_candidate
    font_query="$(to_lower "$1")"
    for font_candidate in "${FONT_LIST_AVAILABLE[@]}"; do
        [[ "$(to_lower "${font_candidate}")" == "${font_query}" ]] && { printf "%s" "${font_candidate}"; return 0; }
    done
    return 1
}

# Partial-match search across FONT_LIST_AVAILABLE
font_search() {
    local search="$1"
    local search_lower matches
    search_lower="$(to_lower "${search}")"
    matches=()
    local font_candidate
    for font_candidate in "${FONT_LIST_AVAILABLE[@]}"; do
        if [[ "$(to_lower "${font_candidate}")" == *"${search_lower}"* ]]; then
            matches+=("${font_candidate}")
        fi
    done
    printf "%s\n" "${matches[@]}"
}

# Add a font to the installation queue (FONT_LIST_SELECTED)
font_add() {
    local font_canonical
    if font_canonical="$(font_resolve "$1")"; then
        local already_selected=0
        local f
        for f in "${FONT_LIST_SELECTED[@]}"; do
            [[ "${f}" == "${font_canonical}" ]] && { already_selected=1; break; }
        done
        if (( already_selected )); then
            log_info "Already selected: %s" "${font_canonical}"
        else
            FONT_LIST_SELECTED+=("${font_canonical}")
            log_success "Selected: %s (%d total)" "${font_canonical}" "${#FONT_LIST_SELECTED[@]}"
        fi
    else
        log_error "Unknown font: %s" "$1"
        return 1
    fi
}

# Remove a font from the installation queue
font_remove() {
    local font_canonical new_selected
    if font_canonical="$(font_resolve "$1")"; then
        new_selected=()
        local f
        for f in "${FONT_LIST_SELECTED[@]}"; do
            [[ "${f}" != "${font_canonical}" ]] && new_selected+=("${f}")
        done
        if (( ${#new_selected[@]} == ${#FONT_LIST_SELECTED[@]} )); then
            log_info "Not selected: %s" "${font_canonical}"
        else
            FONT_LIST_SELECTED=("${new_selected[@]}")
            log_info "Deselected: %s (%d remaining)" "${font_canonical}" "${#FONT_LIST_SELECTED[@]}"
        fi
    else
        log_error "Unknown font: %s" "$1"
        return 1
    fi
}

# =============================================================================
# SYSTEM DETECTION
# =============================================================================

# Detect the font directory based on the operating system
font_dir_detect() {
    FONT_DIR_EXTRA=""
    case "${OS_NAME}" in
        Darwin)
            FONT_DIR="${HOME}/Library/Fonts"
        ;;
        Linux)
            FONT_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/fonts"
        ;;
        CYGWIN*)
            FONT_DIR="$(cygpath -u "${LOCALAPPDATA}")/Microsoft/Windows/Fonts"
            FONT_DIR_EXTRA="${XDG_DATA_HOME:-${HOME}/.local/share}/fonts"
        ;;
        *)
            FONT_DIR="${HOME}/.fonts"
            log_info "Unsupported OS: %s" "${OS_NAME}"
            log_info "Fonts will be installed in %s" "${FONT_DIR}"
            read -r -p "${LOG_PREFIX} Press enter to continue or ctrl+c to exit: " </dev/tty
        ;;
    esac
    mkdir -p "${FONT_DIR}"
    if [ -n "${FONT_DIR_EXTRA:-}" ]; then mkdir -p "${FONT_DIR_EXTRA}"; fi
}

# Check system requirements before proceeding
preflight_check() {
    TOOL_DOWNLOADER=""
    TOOL_ARCHIVER=""
    TOOL_MISSING_LIST=()
    FONT_LIST_SELECTED=()
    FONT_LIST_INSTALLED=()

    OS_NAME="$(uname -s)"

    tool_require_first TOOL_DOWNLOADER curl wget
    tool_require_first TOOL_ARCHIVER tar unzip
    [[ "${OS_NAME}" == CYGWIN* ]] && tool_require_first TOOL_CYGPATH cygpath

    if [ "${#TOOL_MISSING_LIST[@]}" -ne 0 ]; then
        log_error "Missing required tools:"
        local tool_name
        for tool_name in "${TOOL_MISSING_LIST[@]}"; do
            log_error "  - %s" "${tool_name}"
        done
        exit 1
    fi

    # tar.xz is preferred; fall back to .zip when xz is unavailable
    FONT_ARCHIVE_EXTENSION="tar.xz"
    if [ "${TOOL_ARCHIVER}" = "unzip" ]; then
        FONT_ARCHIVE_EXTENSION="zip"
    elif [ "${TOOL_ARCHIVER}" = "tar" ] && ! tar_has_xz_support; then
        if command_exists unzip; then
            TOOL_ARCHIVER="unzip"
            FONT_ARCHIVE_EXTENSION="zip"
            log_info "xz not available; falling back to unzip"
        else
            log_error "tar has no xz support and unzip is not installed. Install xz or unzip."
            exit 1
        fi
    fi

    font_dir_detect
    font_list_set
    TMP_DIR="$(mktemp -d)"

    # Determine Nerd Fonts release URL
    NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-latest}"
    if [ "${NERD_FONTS_VERSION}" != "latest" ] && [[ "${NERD_FONTS_VERSION}" != v* ]]; then
        NERD_FONTS_VERSION="v${NERD_FONTS_VERSION}"
    fi
    if [ "${NERD_FONTS_VERSION}" = "latest" ]; then
        FONT_URL_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    else
        FONT_URL_BASE="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}"
    fi
}

# =============================================================================
# INSTALLED FONT DETECTION
# =============================================================================

# Detect installed Nerd Fonts by scanning font directories.
# Adds found fonts to FONT_LIST_SELECTED (used by --list and update).
font_detect_installed() {
    local font_candidate dir
    for font_candidate in "${FONT_LIST_AVAILABLE[@]}"; do
        for dir in "${FONT_DIR}" "${FONT_DIR_EXTRA:-}"; do
            [[ -z "${dir}" ]] && continue
            if [ -d "${dir}/${font_candidate}" ]; then
                font_add "${font_candidate}"
                break
            fi
            if ls "${dir}/${font_candidate}"[Nn]erd[Ff]ont*.* >/dev/null 2>&1; then
                font_add "${font_candidate}"
                break
            fi
        done
    done
}

# Detect installed Nerd Fonts without modifying FONT_LIST_SELECTED.
# Populates FONT_LIST_INSTALLED for the interactive menu display.
font_detect_installed_all() {
    FONT_LIST_INSTALLED=()
    local font_candidate dir
    for font_candidate in "${FONT_LIST_AVAILABLE[@]}"; do
        for dir in "${FONT_DIR}" "${FONT_DIR_EXTRA:-}"; do
            [[ -z "${dir}" ]] && continue
            if [ -d "${dir}/${font_candidate}" ]; then
                FONT_LIST_INSTALLED+=("${font_candidate}")
                break
            fi
            if ls "${dir}/${font_candidate}"[Nn]erd[Ff]ont*.* >/dev/null 2>&1; then
                FONT_LIST_INSTALLED+=("${font_candidate}")
                break
            fi
        done
    done
}

# =============================================================================
# INTERACTIVE MODE
# =============================================================================

# Render the font selection menu as a multi-column grid.
# * marks fonts in the queue, green text marks installed fonts.
font_menu_show() {
    local font_index menu_width=0
    local font_name
    for font_name in "${FONT_LIST_AVAILABLE[@]}"; do
        (( ${#font_name} > menu_width )) && menu_width=${#font_name}
    done
    menu_width=$(( menu_width + 2 ))
    local term_cols
    term_cols=$(tput cols 2>/dev/null || echo 80)
    local menu_cols=$(( term_cols / (menu_width + 6) ))
    (( menu_cols < 1 )) && menu_cols=1

    local in_queue installed
    for (( font_index=0; font_index<${#FONT_LIST_AVAILABLE[@]}; font_index++ )); do
        in_queue=" "
        for f in "${FONT_LIST_SELECTED[@]}"; do
            [[ "${f}" == "${FONT_LIST_AVAILABLE[${font_index}]}" ]] && { in_queue="*"; break; }
        done
        installed=""
        [[ " ${FONT_LIST_INSTALLED[*]} " == *" ${FONT_LIST_AVAILABLE[${font_index}]} "* ]] && installed=1
        if (( installed )); then
            printf "%3d) %s ${CLR_SUCCESS}%-*s${CLR_RESET}" "$(( font_index+1 ))" "${in_queue}" "${menu_width}" "${FONT_LIST_AVAILABLE[${font_index}]}"
        else
            printf "%3d) %s %-*s" "$(( font_index+1 ))" "${in_queue}" "${menu_width}" "${FONT_LIST_AVAILABLE[${font_index}]}"
        fi
        (( (font_index+1) % menu_cols == 0 )) && printf "\n"
    done
    (( ${#FONT_LIST_AVAILABLE[@]} % menu_cols != 0 )) && printf "\n"
    printf "\n"
}

# Interactive font selection loop. Supports:
#   - Number input (e.g., 5, 1-10, 1,3,5)
#   - Name input (e.g., Hack, FiraCode)
#   - Deselection (e.g., -5, -Hack)
#   - Commands: show, menu, q
font_select_interactive() {
    if ! test -r /dev/tty; then
        log_error "No terminal available. Use: %s <FontName> [FontName...]" "$0"
        exit 1
    fi

    local menu_reply

    # Detect already-installed fonts for menu highlighting
    font_detect_installed_all

    log_info "Nerd Fonts release: %s" "${NERD_FONTS_VERSION}"
    log_info "Install directory: %s" "${FONT_DIR}"
    if [ -n "${FONT_DIR_EXTRA:-}" ]; then
        log_info "Extra directory: %s" "${FONT_DIR_EXTRA}"
    fi
    if (( ${#FONT_LIST_INSTALLED[@]} > 0 )); then
        log_success "%d Nerd Font(s) already installed (shown in green)" "${#FONT_LIST_INSTALLED[@]}"
    fi

    log_info ""
    log_info "Select fonts by number, name, or partial name."
    log_info "  • Ranges: 1-5, 1,3,5"
    log_info "  • Deselect: -5 or -FiraCode"
    log_info "  • Show queue: show  |  Redisplay menu: menu  |  Quit: q or ctrl+c"
    log_info ""
    log_info "Press Enter with empty input to install."
    log_info ""
    font_menu_show

    while read -r -p "${LOG_PREFIX} Select font(s): " menu_reply </dev/tty; do
        [[ "${menu_reply}" == "q" ]] && quit

        if [[ -z "${menu_reply}" ]]; then
            (( ${#FONT_LIST_SELECTED[@]} > 0 )) && break
            log_info "Select at least one font first."
            continue
        fi

        # Show current selection queue
        if [[ "${menu_reply}" == "show" ]]; then
            if (( ${#FONT_LIST_SELECTED[@]} == 0 )); then
                log_info "No fonts selected yet."
            else
                log_success "Selected (%d): %s" "${#FONT_LIST_SELECTED[@]}" "${FONT_LIST_SELECTED[*]}"
            fi
            continue
        fi

        # Redisplay the font menu
        if [[ "${menu_reply}" == "menu" ]]; then
            font_menu_show
            continue
        fi

        # --------------------------------------------------------------------
        # Numeric input parsing (handles numbers, ranges, deselection)
        # --------------------------------------------------------------------
        if [[ "${menu_reply}" =~ ^[0-9,\ \-]+$ ]]; then
            local -a numbers=()
            local part range_start range_end i
            local IFS_old="$IFS"
            IFS=', '
            for part in ${menu_reply}; do
                if [[ "${part}" =~ ^-?[0-9]+$ ]]; then
                    numbers+=("${part}")
                fi
            done
            IFS="$IFS_old"

            # If input contains a dash, reparse to handle ranges (e.g., 1-5)
            if [[ "${menu_reply}" == *-* ]]; then
                numbers=()
                IFS=', '
                for part in ${menu_reply}; do
                    if [[ "${part}" == -* ]]; then
                        # Deselection (e.g., -10)
                        numbers+=("${part}")
                    elif [[ "${part}" == *-* ]]; then
                        # Range (e.g., 1-5)
                        range_start="${part%-*}"
                        range_end="${part#*-}"
                        if [[ "${range_start}" =~ ^[0-9]+$ ]] && [[ "${range_end}" =~ ^[0-9]+$ ]]; then
                            for (( i=range_start; i<=range_end; i++ )); do
                                numbers+=("${i}")
                            done
                        fi
                    else
                        numbers+=("${part}")
                    fi
                done
                IFS="$IFS_old"
            fi

            # Validate all numbers are within range
            local valid=1
            for part in "${numbers[@]}"; do
                local abs_part=$(( part < 0 ? -part : part ))
                if (( abs_part < 1 || abs_part > ${#FONT_LIST_AVAILABLE[@]} )); then
                    log_info "Invalid number: %s. Use 1-%d." "${part}" "${#FONT_LIST_AVAILABLE[@]}"
                    valid=0
                    break
                fi
            done
            (( valid )) || continue

            # Apply selections/deselections
            for part in "${numbers[@]}"; do
                if (( part < 0 )); then
                    font_remove "${FONT_LIST_AVAILABLE[$(( -part - 1 ))]}" || true
                else
                    font_add "${FONT_LIST_AVAILABLE[$(( part - 1 ))]}"
                fi
            done
            continue
        fi

        # --------------------------------------------------------------------
        # Name-based input parsing
        # --------------------------------------------------------------------
        local name_part name_parts
        IFS=', ' read -ra name_parts <<<"${menu_reply}"
        for name_part in "${name_parts[@]}"; do
            [[ -z "${name_part}" ]] && continue
            if [[ "${name_part}" == "-"* ]]; then
                font_remove "${name_part#-}" || true
            elif font_resolve "${name_part}" >/dev/null; then
                font_add "${name_part}"
            else
                local matches
                mapfile -t matches < <(font_search "${name_part}")
                if (( ${#matches[@]} == 0 )); then
                    log_error "No font named or matching: %s" "${name_part}"
                elif (( ${#matches[@]} == 1 )); then
                    font_add "${matches[0]}"
                else
                    log_info "Did you mean one of: %s" "${matches[*]}"
                fi
            fi
        done
    done
}

# =============================================================================
# NON-INTERACTIVE MODE & UPDATE
# =============================================================================

# Parse comma/space-separated font names from CLI arguments
font_select_noninteractive() {
    local -a font_args
    IFS=', ' read -ra font_args <<<"$*"
    local font_arg
    for font_arg in "${font_args[@]}"; do
        font_add "${font_arg}" || true
    done
    if (( ${#FONT_LIST_SELECTED[@]} == 0 )); then
        log_error "No valid fonts selected. Exiting."
        exit 1
    fi
}

# Update mode — reinstall previously installed fonts
font_select_update() {
    if (( $# > 0 )); then
        font_select_noninteractive "$@"
        return
    fi
    if [ "${OS_NAME}" = "Darwin" ]; then
        log_error "Auto-detect not supported on macOS. Name fonts explicitly: %s update <Font> [...]" "$0"
        exit 1
    fi
    log_info "Detecting installed fonts in %s" "${FONT_DIR}"
    font_detect_installed
    if (( ${#FONT_LIST_SELECTED[@]} == 0 )); then
        log_error "No installed Nerd Fonts found in %s" "${FONT_DIR}"
        exit 1
    fi
}

# =============================================================================
# DOWNLOAD & INSTALL
# =============================================================================

# Download a font archive from GitHub releases
file_download() {
    local file_url="$1"
    local file_out_path="$2"
    case "${TOOL_DOWNLOADER}" in
        curl) curl -fsSL -o "${file_out_path}" "${file_url}" ;;
        wget) wget -q -O "${file_out_path}" "${file_url}" ;;
    esac
}

# Extract a font archive (tar.xz or zip)
archive_extract() {
    local archive_path="$1"
    local archive_dest_dir="$2"
    case "${TOOL_ARCHIVER}" in
        tar) tar -xf "${archive_path}" -C "${archive_dest_dir}" ;;
        unzip) unzip -qq -o "${archive_path}" -d "${archive_dest_dir}" ;;
    esac
}

# Download and extract a single font
font_download() {
    local font_name="$1"
    local font_url="$2"
    local font_archive_path="${TMP_DIR}/${font_name}.${FONT_ARCHIVE_EXTENSION}"
    local font_extract_dir="${TMP_DIR}/${font_name}"
    mkdir -p "${font_extract_dir}"
    file_download "${font_url}" "${font_archive_path}"
    archive_extract "${font_archive_path}" "${font_extract_dir}"
}

# Copy font files to the system font directory
font_install() {
    local font_name="$1"
    local font_extract_dir="${TMP_DIR}/${font_name}"
    local font_dest_dir
    font_dest_dir="${FONT_DIR}/${font_name}"
    [ "${OS_NAME}" = "Darwin" ] && font_dest_dir="${FONT_DIR}"

    mkdir -p "${font_dest_dir}"
    find "${font_extract_dir}" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "${font_dest_dir}/" \;

    if [ -n "${FONT_DIR_EXTRA:-}" ]; then
        local font_dest_dir_extra="${FONT_DIR_EXTRA}/${font_name}"
        mkdir -p "${font_dest_dir_extra}"
        find "${font_extract_dir}" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "${font_dest_dir_extra}/" \;
    fi

    case "${OS_NAME}" in CYGWIN*)
        font_register_windows "${font_extract_dir}"
    ;; esac
}

# Register fonts with Windows (Cygwin only) via PowerShell COM
font_register_windows() {
    local font_extract_dir="$1"
    local win_path
    win_path="$(cygpath -w "${font_extract_dir}")" || {
        log_info "Font registration skipped (cygpath not available)"
        return
    }
    log_info "Registering fonts with Windows..."
    powershell.exe -Command "
        \$Shell = New-Object -ComObject Shell.Application;
        \$FontsFolder = \$Shell.Namespace(0x14);
        Get-ChildItem -Path '${win_path}' -Include '*.ttf','*.otf' -Recurse | ForEach-Object {
            \$FontsFolder.CopyHere(\$_.FullName, 0x14) | Out-Null;
        }
    " 2>/dev/null || log_info "Font registration skipped (requires PowerShell)"
}

# Rebuild the font cache on Linux
font_cache_rebuild() {
    local font_failed_count="$1"
    local font_total="$2"
    if (( font_failed_count < font_total )) && command_exists fc-cache; then
        log_info "Rebuilding font cache"
        fc-cache -f
    fi
}

# Install all fonts in the selection queue with progress indicators
font_install_all() {
    local font_failed_count=0
    local font_name font_url total="${#FONT_LIST_SELECTED[@]}"

    log_info ""
    log_info "Installing %d font(s)..." "${total}"
    log_info ""
    for font_name in "${FONT_LIST_SELECTED[@]}"; do
        font_url="${FONT_URL_BASE}/${font_name}.${FONT_ARCHIVE_EXTENSION}"
        log_info "  ${CLR_INFO}→${CLR_RESET} Installing ${font_name}..."
        if ! { font_download "${font_name}" "${font_url}" && font_install "${font_name}"; }; then
            log_error "  ${CLR_ERROR}✗${CLR_RESET} ${font_name} failed"
            font_failed_count=$(( font_failed_count + 1 ))
            continue
        fi
        log_success "  ${CLR_SUCCESS}✓${CLR_RESET} ${font_name} installed"
    done

    font_cache_rebuild "${font_failed_count}" "${total}"

    log_info ""
    if (( font_failed_count > 0 )); then
        log_error "%d of %d font(s) failed." "${font_failed_count}" "${total}"
    fi
    if (( font_failed_count == 0 )); then
        log_success "All fonts installed successfully."
    fi
    return 0
}

# =============================================================================
# OUTPUT — greeting and help
# =============================================================================

greeting() {
    log_info "Nerd Fonts Installer v${NERD_FONTS_INSTALLER_VERSION}"
    log_info "Install Nerd Fonts <https://www.nerdfonts.com/> on Linux and macOS."
    log_info ""
    log_info "GitHub: <https://github.com/officialrajdeepsingh/nerd-fonts-installer>"
    log_info "---"
    log_info ""
}

help_show() {
    cat <<EOF

Install one or more Nerd Fonts on Linux and macOS.

Usage:
  $0                    Run in interactive mode
  $0 interactive        Run in interactive mode
  $0 <font> [...]       Install one or more fonts non-interactively
  $0 update             Reinstall (update) all installed fonts

Examples:
  $0
  $0 interactive
  $0 Monoid
  $0 Monoid Hack
  $0 Monoid,Hack
  $0 update

Commands:
  help, h, -h, --help, /h, /help
      Show this help message

  interactive, i, -i, --interactive, /i, /interactive
      Start interactive font selection

  update, u, -u, --update, /u, /update
      Reinstall installed fonts to the latest release. With no arguments,
      auto-detects installed fonts by scanning the font directory
      (not supported on macOS — name fonts explicitly there).

  list, l, -l, --list, /l, /list
      List Nerd Fonts currently installed on your system.

  version, v, -v, --version, /v, /version
      Print the installer version and exit.

  silent, s, -s, --silent, /s, /silent
  quiet, q, -q, --quiet, /q, /quiet
      Suppress informational output (errors still shown).
      Equivalent to setting LOG_LEVEL=0.

  color, --color, /color
      Force colored output even when not writing to a terminal.
      Equivalent to setting USE_COLOR=1.

  no-color, --no-color, /no-color
      Disable colored output.
      Equivalent to setting USE_COLOR=0.

  nerd-fonts-version=<version>, --nerd-fonts-version=<version>, /nerd-fonts-version=<version>
      Pin a specific Nerd Fonts release (default: latest).
      Equivalent to setting NERD_FONTS_VERSION=<version>.
      Example: $0 --nerd-fonts-version=v3.4.0 Monoid

Notes:
  - Font names are case-insensitive.
  - Multiple fonts may be specified as separate arguments or as a
    comma-separated list.
  - If no arguments are provided, interactive mode is started.
  - Set LOG_LEVEL=0 to suppress informational output (same as --quiet).
EOF
}

# =============================================================================
# FONT LIST DATA — all 70 available Nerd Fonts
# =============================================================================

font_list_set() {
    FONT_LIST_AVAILABLE=(
        "0xProto"
        "3270"
        "AdwaitaMono"
        "Agave"
        "AnonymousPro"
        "Arimo"
        "AtkinsonHyperlegibleMono"
        "AurulentSansMono"
        "BigBlueTerminal"
        "BitstreamVeraSansMono"
        "CascadiaCode"
        "CascadiaMono"
        "CodeNewRoman"
        "ComicShannsMono"
        "CommitMono"
        "Cousine"
        "D2Coding"
        "DaddyTimeMono"
        "DejaVuSansMono"
        "DepartureMono"
        "DroidSansMono"
        "EnvyCodeR"
        "FantasqueSansMono"
        "FiraCode"
        "FiraMono"
        "GeistMono"
        "Go-Mono"
        "Gohu"
        "Hack"
        "Hasklig"
        "HeavyData"
        "Hermit"
        "iA-Writer"
        "IBMPlexMono"
        "Inconsolata"
        "InconsolataGo"
        "InconsolataLGC"
        "IntelOneMono"
        "Iosevka"
        "IosevkaTerm"
        "IosevkaTermSlab"
        "JetBrainsMono"
        "Lekton"
        "LiberationMono"
        "Lilex"
        "MartianMono"
        "Meslo"
        "Monaspace"
        "Monofur"
        "Monoid"
        "Mononoki"
        "MPlus"
        "NerdFontsSymbolsOnly"
        "Noto"
        "OpenDyslexic"
        "Overpass"
        "ProFont"
        "ProggyClean"
        "Recursive"
        "RobotoMono"
        "ShareTechMono"
        "SourceCodePro"
        "SpaceMono"
        "Terminus"
        "Tinos"
        "Ubuntu"
        "UbuntuMono"
        "UbuntuSans"
        "VictorMono"
        "ZedMono"
    )
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

# Clean up temporary files on exit
trap '[ -n "${TMP_DIR:-}" ] && rm -rf "${TMP_DIR}"' EXIT

main() {
    local -a args=()
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --version|-v|/version|/v|version|v) printf "%s\n" "${NERD_FONTS_INSTALLER_VERSION}"; exit 0 ;;
            --silent|--quiet|-q|-s|/q|/quiet|/s|/silent|silent|quiet|q|s) LOG_LEVEL=0 ;;
            --color|/color|color) USE_COLOR=1 ;;
            --no-color|/no-color|no-color) USE_COLOR=0 ;;
            --nerd-fonts-version=*|/nerd-fonts-version=*|nerd-fonts-version=*) NERD_FONTS_VERSION="${arg#*=}" ;;
            *) args+=("${arg}") ;;
        esac
    done
    set -- "${args[@]+"${args[@]}"}"

    setup_colors
    greeting

    # Early exit for help (no preflight needed)
    case "${1:-}" in
        help|-h|--help|/h|/help|h) help_show; return ;;
    esac

    # Setup system paths, tools, and font list
    preflight_check

    # Route to the appropriate mode
    case "${1:-}" in
        list|--list|-l|/list|/l|l)
            LOG_LEVEL=0 font_detect_installed
            if (( ${#FONT_LIST_SELECTED[@]} == 0 )); then
                log_info "No Nerd Fonts installed in %s" "${FONT_DIR}"
                log_info "Run without arguments to select and install fonts."
            else
                log_info "Available fonts"
                local f
                for f in "${FONT_LIST_SELECTED[@]}"; do
                    printf "  ${CLR_SUCCESS}%s${CLR_RESET}\n" "${f}"
                done
            fi
            return
            ;;
        interactive|-i|--interactive|/i|/interactive|i|"") font_select_interactive ;;
        update|--update|/update|-u|/u|u) shift; font_select_update "$@" ;;
        *) font_select_noninteractive "$@" ;;
    esac

    # Install all selected fonts
    font_install_all
}

main "$@"
