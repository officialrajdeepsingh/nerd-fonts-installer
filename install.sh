#!/usr/bin/env bash
# Nerd Fonts Installer
# Install Nerd Fonts <https://www.nerdfonts.com/> on Linux and macOS.
#
# GitHub: <https://github.com/officialrajdeepsingh/nerd-fonts-installer>
# Licenced with MIT. Check LICENSE file for details

set -euo pipefail

readonly NERD_FONTS_INSTALLER_VERSION="2.6.0"
readonly LOG_PREFIX="█▓▒░"
LOG_LEVEL="${LOG_LEVEL:-1}"

setup_colors() {
    USE_COLOR="${USE_COLOR:-auto}"

    CLR_INFO="" CLR_SUCCESS="" CLR_ERROR="" CLR_RESET=""
    if [[ "${USE_COLOR}" == "auto" ]]; then
        [[ -t 1 ]] && USE_COLOR=1 || USE_COLOR=0
    fi
    if (( USE_COLOR )); then
        CLR_INFO="\033[0;36m"
        CLR_SUCCESS="\033[0;32m"
        CLR_ERROR="\033[0;31m"
        CLR_RESET="\033[0m"
    fi
}

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
    case "${1:-}" in
        help|-h|--help|/h|/help|h) help_show; return ;;
    esac

    preflight_check
    case "${1:-}" in
        list|--list|-l|/list|/l|l) printf "%s\n" "${FONT_LIST_AVAILABLE[@]}"; return ;;
        interactive|-i|--interactive|/i|/interactive|i|"") font_select_interactive ;;
        update|--update|/update|-u|/u|u) shift; font_select_update "$@" ;;
        *) font_select_noninteractive "$@" ;;
    esac
    font_install_all
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
      Print all available font names, one per line, then exit.

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

greeting() {
    log_info "Nerd Fonts Installer v${NERD_FONTS_INSTALLER_VERSION}"
    log_info "Install Nerd Fonts <https://www.nerdfonts.com/> on Linux and macOS."
    log_info ""
    log_info "GitHub: <https://github.com/officialrajdeepsingh/nerd-fonts-installer>"
    log_info "---"
    log_info ""
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

tar_has_xz_support() {
    # BSD tar (macOS, libarchive) has built-in xz support
    tar --version 2>&1 | grep -qiE 'bsd|libarchive' && return 0
    # GNU tar delegates to the xz binary
    command_exists xz
}

to_lower() { printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

font_resolve() {
    local font_query font_candidate
    font_query="$(to_lower "$1")"
    for font_candidate in "${FONT_LIST_AVAILABLE[@]}"; do
        [[ "$(to_lower "${font_candidate}")" == "${font_query}" ]] && { printf "%s" "${font_candidate}"; return 0; }
    done
    return 1
}

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

preflight_check() {
    TOOL_DOWNLOADER=""
    TOOL_ARCHIVER=""
    TOOL_MISSING_LIST=()
    FONT_LIST_SELECTED=()

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

    # tar.xz is preferred, but requires xz support.
    # BSD tar (macOS/libarchive) has it built-in; GNU tar needs the xz binary.
    # Fall back to zip/unzip when xz is unavailable.
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

    # To pin a version, set NERD_FONTS_VERSION=v3.4.0 (or similar).
    # If a bare number is given (e.g. 3.4.0), prefix it with v.
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

    local in_queue
    for (( font_index=0; font_index<${#FONT_LIST_AVAILABLE[@]}; font_index++ )); do
        in_queue=" "
        local f
        for f in "${FONT_LIST_SELECTED[@]}"; do
            [[ "${f}" == "${FONT_LIST_AVAILABLE[${font_index}]}" ]] && { in_queue="*"; break; }
        done
        printf "%3d) %s %-*s" "$(( font_index+1 ))" "${in_queue}" "${menu_width}" "${FONT_LIST_AVAILABLE[${font_index}]}"
        (( (font_index+1) % menu_cols == 0 )) && printf "\n"
    done
    (( ${#FONT_LIST_AVAILABLE[@]} % menu_cols != 0 )) && printf "\n"
    printf "\n%3d) Quit\n\n" "$(( ${#FONT_LIST_AVAILABLE[@]} + 1 ))"
}

font_select_interactive() {
    if ! test -r /dev/tty; then
        log_error "No terminal available. Use: %s <FontName> [FontName...]" "$0"
        exit 1
    fi

    local menu_quit_index=$(( ${#FONT_LIST_AVAILABLE[@]} + 1 ))
    local menu_reply

    log_info "Nerd Fonts release: %s" "${NERD_FONTS_VERSION}"
    log_info "Install directory: %s" "${FONT_DIR}"
    if [ -n "${FONT_DIR_EXTRA:-}" ]; then
        log_info "Extra directory: %s" "${FONT_DIR_EXTRA}"
    fi
    
    log_info ""
    log_info "Select fonts by number, name, or partial name."
    log_info "  • Ranges: 1-5, 1,3,5"
    log_info "  • Deselect: -5 or -FiraCode"
    log_info "  • Show queue: show  |  Redisplay menu: menu  |  Quit: q"
    log_info ""
    log_info "Press Enter with empty input to install."
    font_menu_show

    while read -r -p "${LOG_PREFIX} Select font(s): " menu_reply </dev/tty; do
        [[ "${menu_reply}" == "q" ]] && quit

        if [[ -z "${menu_reply}" ]]; then
            (( ${#FONT_LIST_SELECTED[@]} > 0 )) && break
            log_info "Select at least one font first."
            continue
        fi

        if [[ "${menu_reply}" == "show" ]]; then
            if (( ${#FONT_LIST_SELECTED[@]} == 0 )); then
                log_info "No fonts selected yet."
            else
                log_success "Selected (%d): %s" "${#FONT_LIST_SELECTED[@]}" "${FONT_LIST_SELECTED[*]}"
            fi
            continue
        fi

        if [[ "${menu_reply}" == "menu" ]]; then
            font_menu_show
            continue
        fi

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
            if [[ "${menu_reply}" == *-* ]]; then
                numbers=()
                IFS=', '
                for part in ${menu_reply}; do
                    if [[ "${part}" == -* ]]; then
                        numbers+=("${part}")
                    elif [[ "${part}" == *-* ]]; then
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
            local valid=1
            for part in "${numbers[@]}"; do
                if (( part < 1 || part > menu_quit_index )); then
                    log_info "Invalid number: %s. Use 1-%d." "${part}" "${menu_quit_index}"
                    valid=0
                    break
                fi
            done
            (( valid )) || continue
            for part in "${numbers[@]}"; do
                (( part == menu_quit_index )) && quit
                if (( part < 0 )); then
                    font_remove "${FONT_LIST_AVAILABLE[$(( -part - 1 ))]}" || true
                else
                    font_add "${FONT_LIST_AVAILABLE[$(( part - 1 ))]}"
                fi
            done
            continue
        fi

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
                matches=($(font_search "${name_part}"))
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

font_detect_installed() {
    local entry name
    for entry in "${FONT_DIR}"/*/; do
        [ -d "${entry}" ] || continue
        name="$(basename "${entry%/}")"
        font_resolve "${name}" >/dev/null 2>&1 && font_add "${name}" || true
    done
}

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

file_download() {
    local file_url="$1"
    local file_out_path="$2"

    case "${TOOL_DOWNLOADER}" in
        curl) curl -fsSL -o "${file_out_path}" "${file_url}" ;;
        wget) wget -q -O "${file_out_path}" "${file_url}" ;;
    esac
}

archive_extract() {
    local archive_path="$1"
    local archive_dest_dir="$2"

    case "${TOOL_ARCHIVER}" in
        tar) tar -xf "${archive_path}" -C "${archive_dest_dir}" ;;
        unzip) unzip -qq -o "${archive_path}" -d "${archive_dest_dir}" ;;
    esac
}

font_download() {
    local font_name="$1"
    local font_url="$2"

    local font_archive_path="${TMP_DIR}/${font_name}.${FONT_ARCHIVE_EXTENSION}"
    local font_extract_dir="${TMP_DIR}/${font_name}"

    mkdir -p "${font_extract_dir}"

    file_download "${font_url}" "${font_archive_path}"
    archive_extract "${font_archive_path}" "${font_extract_dir}"
}

font_install() {
    local font_name="$1"
    local font_extract_dir="${TMP_DIR}/${font_name}"
    local font_dest_dir
    font_dest_dir="${FONT_DIR}/${font_name}"
    [ "${OS_NAME}" = "Darwin" ] && font_dest_dir="${FONT_DIR}"

    mkdir -p "${font_dest_dir}"
    log_info "Installing font %s in %s" "${font_name}" "${font_dest_dir}"
    find "${font_extract_dir}" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "${font_dest_dir}/" \;

    if [ -n "${FONT_DIR_EXTRA:-}" ]; then
        local font_dest_dir_extra="${FONT_DIR_EXTRA}/${font_name}"
        mkdir -p "${font_dest_dir_extra}"
        log_info "Installing font %s in %s" "${font_name}" "${font_dest_dir_extra}"
        find "${font_extract_dir}" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "${font_dest_dir_extra}/" \;
    fi

    case "${OS_NAME}" in CYGWIN*)
        font_register_windows "${font_extract_dir}"
    ;; esac
}

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

font_cache_rebuild() {
    local font_failed_count="$1"
    local font_total="$2"
    if (( font_failed_count < font_total )) && command_exists fc-cache; then
        log_info "Rebuilding font cache"
        fc-cache -f
    fi
}

font_install_all() {
    local font_failed_count=0
    local font_name font_url
    for font_name in "${FONT_LIST_SELECTED[@]}"; do
        font_url="${FONT_URL_BASE}/${font_name}.${FONT_ARCHIVE_EXTENSION}"
        if ! { font_download "${font_name}" "${font_url}" && font_install "${font_name}"; }; then
            log_error "Failed: %s (skipping)" "${font_name}"
            font_failed_count=$(( font_failed_count + 1 ))
            continue
        fi
        log_success "Installed: %s" "${font_name}"
    done

    font_cache_rebuild "${font_failed_count}" "${#FONT_LIST_SELECTED[@]}"

    (( font_failed_count > 0 )) && log_error "%d of %d font(s) failed." "${font_failed_count}" "${#FONT_LIST_SELECTED[@]}"
    (( font_failed_count == 0 )) && log_success "All fonts installed successfully."
    return 0
}

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

main "$@"
