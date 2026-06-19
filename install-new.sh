#!/usr/bin/env bash
# Select the Nerd Font from https://www.nerdfonts.com/font-downloads

# fc-cache may not exist on some systems. Do not rebuild cache in this case
# MacOS may ignore fonts inside subdirectories of ~/Library/Fonts
# Modern Linux font dir is ~/.local/share/fonts/ but ~/.fonts is still supported
# NerdFonts also distributed as tar.xz. Less to download, no unzip dependency. ZIP as fallback
# non-interactive run: `cat install-new.sh | bash -s -- monoid`
# interactive run: `cat install-new.sh | bash -s -- interactive` or `cat install-new.sh | bash`

set -euo pipefail

trap '[ -n "${TMP_DIR:-}" ] && rm -rf "${TMP_DIR}"' EXIT

main() {
    case "${1:-}" in
        help|-h|--help|/h|/help)
            help_show
        ;;
        interactive|-i|--interactive|/i|/interactive)
            main_interactive
        ;;
        "")
            main_interactive
        ;;
        *)
            main_noninteractive "$@"
        ;;
    esac
}

help_show() {
    cat <<EOF
Nerd Fonts Installer

Install one or more Nerd Fonts on Linux and macOS.

Usage:
  $0                    Run in interactive mode
  $0 interactive        Run in interactive mode
  $0 <font> [...]       Install one or more fonts non-interactively

Examples:
  $0
  $0 interactive
  $0 Monoid
  $0 Monoid Hack
  $0 Monoid,Hack

Commands:
  help, -h, --help, /h, /help
      Show this help message

  interactive, -i, --interactive, /i, /interactive
      Start interactive font selection

Notes:
  - Font names are case-insensitive.
  - Multiple fonts may be specified as separate arguments or as a
    comma-separated list.
  - If no arguments are provided, interactive mode is started.
  - Set NERD_FONTS_VERSION to pin a release (default: latest).
    Example: NERD_FONTS_VERSION=v3.4.0 $0 Monoid
EOF
}

quit() {
    printf "Exiting. Have a nice day\n"
    exit 0
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

font_resolve() {
    local font_query="${1,,}" font_candidate
    for font_candidate in "${FONT_LIST_AVAILABLE[@]}"; do
        [[ "${font_candidate,,}" == "${font_query}" ]] && { printf "%s" "${font_candidate}"; return 0; }
    done
    return 1
}

font_add() {
    local font_canonical
    if font_canonical="$(font_resolve "$1")"; then
        FONT_LIST_SELECTED+=("${font_canonical}")
        printf "Added: %s\n" "${font_canonical}"
    else
        printf "Unknown font: %s (skipping)\n" "$1" >&2
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

    tool_require_first TOOL_DOWNLOADER wget curl
    tool_require_first TOOL_ARCHIVER tar unzip

    if [ "${#TOOL_MISSING_LIST[@]}" -ne 0 ]; then
        printf "Missing required tools:\n"
        local tool_name
        for tool_name in "${TOOL_MISSING_LIST[@]}"; do
            printf " - %s\n" "${tool_name}"
        done
        exit 1
    fi

    FONT_ARCHIVE_EXTENSION="tar.xz"
    [ "${TOOL_ARCHIVER}" = "unzip" ] && FONT_ARCHIVE_EXTENSION="zip"

    OS_NAME="$(uname -s)"
    font_dir_detect
    font_list_set
    TMP_DIR="$(mktemp -d)"

    # To pin a version, set NERD_FONTS_VERSION=v3.4.0 (or similar).
    NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-latest}"
    if [ "${NERD_FONTS_VERSION}" = "latest" ]; then
        FONT_URL_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    else
        FONT_URL_BASE="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}"
    fi
}

font_dir_detect() {
    case "${OS_NAME}" in
        Darwin)
            FONT_DIR="${HOME}/Library/Fonts"
        ;;
        Linux)
            FONT_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/fonts"
        ;;
        *)
            FONT_DIR="${HOME}/.fonts"
            printf "Unsupported OS_NAME: %s\nFonts would be installed in %s\n" \
            "${OS_NAME}" "${FONT_DIR}"
            read -r -p "Press enter to continue or ctrl+c to exit" </dev/tty
        ;;
    esac

    mkdir -p "${FONT_DIR}"
}

font_menu_show() {
    local font_index menu_cols=4 menu_width=26
    for (( font_index=0; font_index<${#FONT_LIST_AVAILABLE[@]}; font_index++ )); do
        printf "%3d) %-*s" "$(( font_index+1 ))" "${menu_width}" "${FONT_LIST_AVAILABLE[${font_index}]}"
        (( (font_index+1) % menu_cols == 0 )) && printf "\n"
    done
    (( ${#FONT_LIST_AVAILABLE[@]} % menu_cols != 0 )) && printf "\n"
    printf "%3d) Quit\n" "$(( ${#FONT_LIST_AVAILABLE[@]} + 1 ))"
}

font_select_interactive() {
    if ! test -r /dev/tty; then
        printf "No terminal available. Use: %s <FontName> [FontName...]\n" "$0" >&2
        exit 1
    fi

    FONT_LIST_SELECTED=()
    local menu_quit_index=$(( ${#FONT_LIST_AVAILABLE[@]} + 1 ))
    local menu_reply

    printf "Select Nerd Fonts to install (press Enter with no input when done):\n"
    font_menu_show

    while read -r -p "Enter a number or press Enter to install: " menu_reply </dev/tty; do
        if [[ -z "${menu_reply}" ]]; then
            if (( ${#FONT_LIST_SELECTED[@]} == 0 )); then
                printf "No fonts selected. Please select at least one font.\n"
                continue
            fi
            break
        fi
        if [[ ${menu_reply} == "q" ]]; then
            quit
        fi

        if [[ "${menu_reply}" =~ ^[0-9]+$ ]] && (( menu_reply >= 1 && menu_reply <= menu_quit_index )); then
            if (( menu_reply == menu_quit_index )); then
                quit
            fi
            font_add "${FONT_LIST_AVAILABLE[$((menu_reply-1))]}"
        else
            printf "Select a valid number between 1 and %d.\n" "${menu_quit_index}"
        fi
    done
}

font_select_noninteractive() {
    FONT_LIST_SELECTED=()
    local -a font_args
    IFS=', ' read -ra font_args <<<"$*"
    local font_arg
    for font_arg in "${font_args[@]}"; do
        font_add "${font_arg}" || true
    done
    if (( ${#FONT_LIST_SELECTED[@]} == 0 )); then
        printf "No valid fonts selected. Exiting.\n" >&2
        exit 1
    fi
}

file_download() {
    local file_url="$1"
    local file_out_path="$2"

    case "${TOOL_DOWNLOADER}" in
        curl) curl -fsSL -o "${file_out_path}" "${file_url}" ;;
        wget) wget -nv -O "${file_out_path}" "${file_url}" ;;
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
    printf "Installing font %s in %s\n" "${font_name}" "${font_dest_dir}"

    find "${font_extract_dir}" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "${font_dest_dir}/" \;
}

font_install_all() {
    local font_failed_count=0
    local font_name font_url
    for font_name in "${FONT_LIST_SELECTED[@]}"; do
        font_url="${FONT_URL_BASE}/${font_name}.${FONT_ARCHIVE_EXTENSION}"
        if ! { font_download "${font_name}" "${font_url}" && font_install "${font_name}"; }; then
            printf "Failed: %s (skipping)\n" "${font_name}" >&2
            font_failed_count=$(( font_failed_count + 1 ))
            continue
        fi
    done

    if command_exists fc-cache; then
        printf "Rebuilding font cache:\n"
        fc-cache -f
    fi

    (( font_failed_count > 0 )) && printf "%d font(s) failed to install.\n" "${font_failed_count}" >&2
    return 0
}

main_interactive() {
    preflight_check
    font_select_interactive
    font_install_all
}

main_noninteractive() {
    preflight_check
    font_select_noninteractive "$@"
    font_install_all
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
