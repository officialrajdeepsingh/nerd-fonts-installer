#!/usr/bin/env bash
# Select the Nerd Font from https://www.nerdfonts.com/font-downloads

# fc-cache may not exist on some systems. Do not rebuild cache in this case
# MacOS may ignore fonts inside subdirectories of ~/Library/Fonts
# Modern Linux font dir is ~/.local/share/fonts/ but ~/.fonts is still supported
# NerdFonts also distributed as tar.xz. Less to download, no unzip dependency. ZIP as fallback

set -e

DOWNLOADER=""
ARCHIVER=""
MISSING_TOOLS=()

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

The Nerd Fonts installer provides cross-platform scripts to easily install Nerd Fonts from the command line. It includes a bash script for Linux and macOS systems, and a PowerShell script for Windows systems.

Usage: $0 [command]

Commands:
  help    Show this help message

If no command is provided, the script runs normally.
EOF
}

have() {
  command -v "$1" >/dev/null 2>&1
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
  FONTS_TO_INSTALL=()
  local quit_index=$(( ${#FONTS_LIST[@]} + 1 ))
  local reply

  printf "Select Nerd Fonts to install (press Enter with no input when done):\n"
  print_font_menu

  while read -r -p "Enter a number: " reply; do
    if [[ -z "$reply" ]]; then
      if (( ${#FONTS_TO_INSTALL[@]} == 0 )); then
        printf "No fonts selected. Please select at least one font.\n"
        continue
      fi
      break
    fi
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= quit_index )); then
      if (( reply == quit_index )); then
        printf "Exiting. Have a nice day\n"
        exit 0
      fi
      FONTS_TO_INSTALL+=("${FONTS_LIST[$((reply-1))]}")
      printf "Added: %s\n" "${FONTS_LIST[$((reply-1))]}"
    else
      printf "Select a valid number between 1 and %d.\n" "${quit_index}"
    fi
  done
}

non_interactive_select_font_to_install() {
  # support both:
  # ./install.sh FiraCode,Monoid
  # ./install.sh FiraCode Monoid
  :
}

download_font() {
  local font_name="$1"
  local font_url="$2"
  local archive="${TMP_DIR}/${font_name}.${FONT_ARCHIVE_EXTENSION}"
  local extract_dir="${TMP_DIR}/${font_name}"

  mkdir -p "${extract_dir}"

  printf "downloader app is %s\n" "${DOWNLOADER}"
  printf "Downloading font %s from url %s\n" "${font_name}" "${font_url}"

  if [ "${DOWNLOADER}" = "curl" ]; then
    curl -fsSL -o "${archive}" "${font_url}"
  else
    wget -nv -O "${archive}" "${font_url}"
  fi || {
    printf "Failed to download %s\n" "${font_name}" >&2
    exit 1
  }

  printf "archiver app is %s\n" "${ARCHIVER}"

  if [ "${ARCHIVER}" = "tar" ]; then
    tar -xf "${archive}" -C "${extract_dir}"
  else
    unzip -qq -o "${archive}" -d "${extract_dir}"
  fi || {
    printf "Failed to unpack %s\n" "${font_name}" >&2
    exit 1
  }
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

main() {
  [ "${ARCHIVER}" = "unzip" ] && FONT_ARCHIVE_EXTENSION="zip"
  detect_font_dir
  interactive_select_font_to_install
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

case "${1:-}" in
  help|-h|--help)
    print_help
    exit 0
    ;;
esac
# if no arguments, run interactive mode
# if more than 0 arguments, run non-interactive selector first

preflight_check
main "$@"
