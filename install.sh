#!/usr/bin/env bash
# Select the Nerd Font from https://www.nerdfonts.com/font-downloads
# Testing with ShellCheck

echo "[-] Download The Nerd fonts [-]"
echo "#######################"
echo "Select Nerd Font"
fonts_list=("0xProto" "3270" "AdwaitaMono" "Agave" "AnonymousPro" "Arimo" "AtkinsonHyperlegibleMono" "AurulentSansMono" "BigBlueTerminal" "BitstreamVeraSansMono" "CascadiaCode" "CascadiaMono" "CodeNewRoman" "ComicShannsMono" "CommitMono" "Cousine" "D2Coding" "DaddyTimeMono" "DejaVuSansMono" "DepartureMono" "DroidSansMono" "EnvyCodeR" "FantasqueSansMono" "FiraCode" "FiraMono" "GeistMono" "Go-Mono" "Gohu" "Hack" "Hasklig" "HeavyData" "Hermit" "iA-Writer" "IBMPlexMono" "Inconsolata" "InconsolataGo" "InconsolataLGC" "IntelOneMono" "Iosevka" "IosevkaTerm" "IosevkaTermSlab" "JetBrainsMono" "Lekton" "LiberationMono" "Lilex" "MartianMono" "Meslo" "Monaspace" "Monofur" "Monoid" "Mononoki" "MPlus" "NerdFontsSymbolsOnly" "Noto" "OpenDyslexic" "Overpass" "ProFont" "ProggyClean" "Recursive" "RobotoMono" "ShareTechMono" "SourceCodePro" "SpaceMono" "Terminus" "Tinos" "Ubuntu" "UbuntuMono" "UbuntuSans" "VictorMono" "ZedMono")
PS3="Enter a number: "
select font_name in "${fonts_list[@]}" "Quit";
 do
    if [[ "$REPLY" =~ ^[0-9]+$ ]] &&
        (( REPLY >= 1 && REPLY <= 71 )); then

        if [[ "$REPLY" = 71 ]]; then
            echo "Exiting. Have a nice day"
            exit 0
        fi
        echo "Starting download $font_name nerd font"

        if [ "$(command -v curl)" ]; then
            echo "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
            curl -OL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
            echo "creating fonts folder: ${HOME}/.fonts"
            mkdir -p  "$HOME/.fonts"
            echo "unzip the $font_name.zip"
            unzip "$font_name.zip" -d "$HOME/.fonts/$font_name/"
            rm -f "$font_name.zip"
            fc-cache -fv
            echo "done!"
            break

        elif [ "$(command -v wget)" ]; then
            echo "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
            wget "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
            echo "creating fonts folder: ${HOME}/.fonts"
            mkdir -p  "$HOME/.fonts"
            echo "unzip the $font_name.zip"
            unzip "$font_name.zip" -d "$HOME/.fonts/$font_name/"
            rm -f "$font_name.zip"
            fc-cache -fv
            echo "done!"
            break

        else

            echo "We cannot find the curl and wget command. First, install the curl and wget command, one of them."
            break

        fi

    else

        echo "Select a valid Nerd Font, just type a number between 1-70."
        continue;

    fi
done
