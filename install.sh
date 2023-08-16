#/bin/bash
# Select the Nerd Font from https://www.nerdfonts.com/font-downloads

echo "[-] Download The Nerd fonts [-]"
echo "#######################"
echo "Enter the Nerd Font Name:"  
read font_name
if [ -n "$font_name" ]; then
    if [ "$(command -v curl)" ]; then
        echo "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
        curl -OL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
    elif [ "$(command -v wget)" ]; then
        echo "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
        wget "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
    else
        echo "We cannot find the curl and wget command. First, install the curl and wget command, one of them."
    fi
    echo "nzip the $font_name.zip"
    unzip "$font_name.zip" -d ~/.fonts
    fc-cache -fv
    echo "done!"
else
    echo "Please provide the nerd font name. Example: JetBrainsMono"
fi