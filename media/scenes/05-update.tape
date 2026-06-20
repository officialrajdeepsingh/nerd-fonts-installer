Type "# Currently we have some fonts installed with the script:"
Sleep 2s
Enter
Sleep 1s
Type "ls -lah ${HOME}/.local/share/fonts"
Enter
Sleep 2s

Type "# And we can update them automatically (Only on Linux or from cygwin):"
Sleep 2s
Enter

Type "./install.sh update"
Enter
Wait
Sleep 200ms
Screenshot media/screenshots/05-update.png
Sleep 5s

Type "ls -lah ${HOME}/.local/share/fonts"
Enter
Sleep 3s

Sleep 500ms
