#!/usr/bin/env bash
# Select the Nerd Font from https://www.nerdfonts.com/font-downloads

# fc-cache may not exist on some systems. Do not rebuild cache in this case
# MacOS may ignore fonts inside subdirectories of ~/Library/Fonts
# Modern Linux font dir is ~/.local/share/fonts/ but ~/.fonts is still supported
# NerdFonts also distributed as tar.xz. Less to download, no unzip dependency. ZIP as fallback
# non-interactive run: `cat install-new.sh | bash -s -- monoid`
# interactive run: `cat install-new.sh | bash -s -- interactive` or `cat install-new.sh | bash`

set -e

DOWNLOADER=""
ARCHIVER=""
MISSING_TOOLS=()
NERD_FONTS_FALLBACK_VERSION="v3.4.0" # Add fallback in case latest works not so well. Add check if fallback is needed to preflight #TODO
FONTS_LIST=(
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
FONT_URL_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
FONT_ARCHIVE_EXTENSION="tar.xz"


print_help() {
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
EOF
}
quit() {
    printf "Exiting. Have a nice day\n"
    exit 0
}
have() {
    command -v "$1" >/dev/null 2>&1
}

resolve_font() {
    local query="${1,,}" entry
    for entry in "${FONTS_LIST[@]}"; do
        [[ "${entry,,}" == "${query}" ]] && { printf "%s" "${entry}"; return 0; }
    done
    return 1
}

add_font() {
    local canonical
    if canonical="$(resolve_font "$1")"; then
        FONTS_TO_INSTALL+=("${canonical}")
        printf "Added: %s\n" "${canonical}"
    else
        printf "Unknown font: %s (skipping)\n" "$1" >&2
        return 1
    fi
}

require_one() {
    local outvar="$1"
    shift

    for cmd in "$@"; do
        if have "${cmd}"; then
            printf -v "${outvar}" "%s" "${cmd}"
            return 0
        fi
    done

    MISSING_TOOLS+=("$(printf "%s or %s" "$@")")
}

preflight_check() {
    require_one DOWNLOADER wget curl
    require_one ARCHIVER tar unzip
    if [ "${#MISSING_TOOLS[@]}" -ne 0 ]; then
        printf "Missing required tools:\n"
        for t in "${MISSING_TOOLS[@]}"; do
            printf " - %s\n" "${t}"
        done
        exit 1
    fi
    detect_font_dir
}

detect_font_dir() {
    case "$(uname -s)" in
        Darwin)
            FONT_DIR="${HOME}/Library/Fonts"
        ;;
        Linux)
            FONT_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/fonts"
        ;;
        *)
            FONT_DIR="${HOME}/.fonts"
            printf "Unsupported OS: %s\nFonts would be installed in %s\n" \
            "$(uname -s)" "${FONT_DIR}"
            read -p "Press enter to continue or ctrl+c to exit"
        ;;
    esac

    mkdir -p "${FONT_DIR}"
}

print_font_menu() {
    local i cols=4 width=26
    for (( i=0; i<${#FONTS_LIST[@]}; i++ )); do
        printf "%3d) %-*s" "$(( i+1 ))" "${width}" "${FONTS_LIST[$i]}"
        (( (i+1) % cols == 0 )) && printf "\n"
    done
    (( ${#FONTS_LIST[@]} % cols != 0 )) && printf "\n"
    printf "%3d) Quit\n" "$(( ${#FONTS_LIST[@]} + 1 ))"
}

interactive_select_font_to_install() {
    if ! test -r /dev/tty; then
        printf "No terminal available. Use: %s <FontName> [FontName...]\n" "$0" >&2
        exit 1
    fi

    FONTS_TO_INSTALL=()
    local quit_index=$(( ${#FONTS_LIST[@]} + 1 ))
    local reply

    printf "Select Nerd Fonts to install (press Enter with no input when done):\n"
    print_font_menu

    while read -r -p "Enter a number or press Enter to install: " reply </dev/tty; do
        if [[ -z "$reply" ]]; then
            if (( ${#FONTS_TO_INSTALL[@]} == 0 )); then
                printf "No fonts selected. Please select at least one font.\n"
                continue
            fi
            break
        fi
        if [[ $reply == "q" ]]; then
            quit
        fi

        if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= quit_index )); then
            if (( reply == quit_index )); then
                quit
            fi
            add_font "${FONTS_LIST[$((reply-1))]}"
        else
            printf "Select a valid number between 1 and %d.\n" "${quit_index}"
        fi
    done
}

non_interactive_select_font_to_install() {
    FONTS_TO_INSTALL=()
    local token
    for token in $(printf '%s' "$*" | tr ',' ' '); do
        add_font "${token}" || true
    done
    if (( ${#FONTS_TO_INSTALL[@]} == 0 )); then
        printf "No valid fonts selected. Exiting.\n" >&2
        exit 1
    fi
}

download_file() {
    local url="$1"
    local out="$2"

    case "$DOWNLOADER" in
        curl) curl -fsSL -o "$out" "$url" ;;
        wget) wget -nv -O "$out" "$url" ;;
    esac
}

extract_archive() {
    local archive="$1"
    local dir="$2"

    case "$ARCHIVER" in
        tar) tar -xf "$archive" -C "$dir" ;;
        unzip) unzip -qq -o "$archive" -d "$dir" ;;
    esac
}

download_font() {
    local font_name="$1"
    local font_url="$2"

    local archive="${TMP_DIR}/${font_name}.${FONT_ARCHIVE_EXTENSION}"
    local extract_dir="${TMP_DIR}/${font_name}"

    mkdir -p "$extract_dir"

    download_file "$font_url" "$archive" || exit 1
    extract_archive "$archive" "$extract_dir" || exit 1
}

install_font(){
    local font_name="$1"
    local extract_dir="${TMP_DIR}/${font_name}"
    local dest_dir

    case "$(uname -s)" in
        Darwin)
            dest_dir="${FONT_DIR}"
        ;;
        *)
            dest_dir="${FONT_DIR}/${font_name}"
        ;;
    esac

    mkdir -p "${dest_dir}"
    printf "Installing font %s in %s\n" "${font_name}" "${dest_dir}"

    find "${extract_dir}" \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "${dest_dir}/" \;
}
download_and_install () {
    [ "${ARCHIVER}" = "unzip" ] && FONT_ARCHIVE_EXTENSION="zip"

    for FONT_NAME in "${FONTS_TO_INSTALL[@]}"; do
        FONT_URL="${FONT_URL_BASE}/${FONT_NAME}.${FONT_ARCHIVE_EXTENSION}"
        download_font "${FONT_NAME}" "${FONT_URL}"
        install_font "${FONT_NAME}"
    done

    if have fc-cache; then
        printf "Rebuilding font cache:\n"
        fc-cache -f
    fi
}

main_interactive() {
    preflight_check
    interactive_select_font_to_install
    download_and_install
}

main_non_interactive() {
    preflight_check
    non_interactive_select_font_to_install "$@"
    download_and_install
}

main() {
    case "${1:-}" in
        help|-h|--help|/h|/help)
            print_help
        ;;
        interactive|-i|--interactive|/i|/interactive)
            main_interactive
        ;;
        "")
            main_interactive
        ;;
        *)
            main_non_interactive "$@"
        ;;
    esac
}

main "$@"
