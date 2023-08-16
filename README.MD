The Nerd fonts installer is a bash based script to install the nerd front in debian distro.

## Download the script
download the nerd fonts installer script using `curl` command. To run nerd fonts installer run following command.

```bash
sh -c "$(curl https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh)"
```
After select your font and your font is start download. 
Verify your font with fc-list command.

```
fc-list : family 
# or
fc-list | grep -i nerd-font-name

```