#!/bin/bash
# Select the Nerd Font from https://www.nerdfonts.com/font-downloads

set -euo pipefail

get_fonts_dir() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        printf '%s\n' "${HOME}/Library/Fonts"
    else
        printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
    fi
}

download_font() {
    local url=$1
    local output_file=$2

    if ! command -v unzip >/dev/null 2>&1; then
        echo "Error: unzip is required to extract downloaded fonts." >&2
        return 1
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "${output_file}" "${url}"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "${output_file}" "${url}"
    else
        echo "Error: curl or wget is required to download fonts." >&2
        return 1
    fi
}

refresh_font_cache() {
    local fonts_dir=${1:-}
    if command -v fc-cache >/dev/null 2>&1; then
        if [[ -n "${fonts_dir}" ]]; then
            fc-cache -fv "${fonts_dir}"
        else
            fc-cache -fv
        fi
    else
        echo "fc-cache not found; skipping font cache refresh."
    fi
}

echo "[-] Download The Nerd fonts [-]"
echo "#######################"
echo "Select Nerd Font"
fonts_list=(
    "0xProto" "3270" "AdwaitaMono" "Agave" "AnonymousPro" "Arimo"
    "AtkinsonHyperlegibleMono" "AurulentSansMono" "BigBlueTerminal" "BitstreamVeraSansMono"
    "CascadiaCode" "CascadiaMono" "CodeNewRoman" "ComicShannsMono" "CommitMono" "Cousine"
    "D2Coding" "DaddyTimeMono" "DejaVuSansMono" "DepartureMono" "DroidSansMono"
    "EnvyCodeR" "FantasqueSansMono" "FiraCode" "FiraMono" "GeistMono" "Go-Mono"
    "Gohu" "Hack" "Hasklig" "HeavyData" "Hermit" "iA-Writer" "IBMPlexMono"
    "Inconsolata" "InconsolataGo" "InconsolataLGC" "IntelOneMono" "Iosevka"
    "IosevkaTerm" "IosevkaTermSlab" "JetBrainsMono" "Lekton" "LiberationMono"
    "Lilex" "MartianMono" "Meslo" "Monaspace" "Monofur" "Monoid" "Mononoki"
    "MPlus" "NerdFontsSymbolsOnly" "Noto" "OpenDyslexic" "Overpass" "ProFont"
    "ProggyClean" "Recursive" "RobotoMono" "ShareTechMono" "SourceCodePro"
    "SpaceMono" "Terminus" "Tinos" "Ubuntu" "UbuntuMono" "UbuntuSans" "VictorMono" "ZedMono"
)
PS3="Enter a number: "
quit_option=$(( ${#fonts_list[@]} + 1 ))
select font_name in "${fonts_list[@]}" "Quit";
 do
    if [[ "${REPLY}" =~ ^[0-9]+$ ]] &&
        (( REPLY >= 1 && REPLY <= quit_option )); then

        if (( REPLY == quit_option )); then
            echo "Exiting. Have a nice day"
            exit 0
        fi
        download_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
        fonts_dir="$(get_fonts_dir)"
        install_dir="${fonts_dir}/${font_name}"
        temp_dir="$(mktemp -d)" || { echo "Error: Failed to create temp directory" >&2; exit 1; }
        zip_file="${temp_dir}/${font_name}.zip"

        echo "Starting download ${font_name} nerd font"
        echo "${download_url}"
        if ! download_font "${download_url}" "${zip_file}"; then
            echo "Error: Failed to download ${font_name}" >&2
            rm -rf "${temp_dir}"
            exit 1
        fi

        echo "creating fonts folder: ${fonts_dir}"
        mkdir -p "${install_dir}"
        echo "unzip the ${zip_file}"
        if ! unzip -o "${zip_file}" -d "${install_dir}"; then
            echo "Error: Failed to extract ${zip_file}" >&2
            rm -rf "${temp_dir}"
            exit 1
        fi
        rm -rf "${temp_dir}"

        refresh_font_cache "${fonts_dir}"
        echo "done!"
        echo "If this installer helped you, please star the repository:"
        echo "https://github.com/officialrajdeepsingh/nerd-fonts-installer"
        echo "If you found a bug or have a feature request, please open an issue:"
        echo "https://github.com/officialrajdeepsingh/nerd-fonts-installer/issues/new"
        break

    else

        echo "Select a valid Nerd Font, just type a number between 1-${quit_option}."
        continue

    fi
done
