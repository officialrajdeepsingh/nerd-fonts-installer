Type@0s "# Let's install fonts interacively:"
Sleep 2s
Enter
Type "./install.sh"
Enter
Sleep 2000ms
Type "# We can install fonts by id"
Sleep 2s
Backspace@0s 1000
Type "50"
Enter
Sleep 1s

Type "# One font was added to queue"
Sleep 2s
Backspace@0s 1000
Type "# Also we can install fonts by font name. You need no obey font name case, btw"
Sleep 2s
Backspace@0s 1000
Type "fIrAcOdE"
Enter
Sleep 1s

Type "# In case of wrong name or id it won't be added to queue"
Sleep 2s
Enter
Sleep 1s

Type "# Just press Enter to install fonts in queue"
Sleep 2s
Backspace@0s 1000
Enter
Wait
Screenshot media/screenshots/02-interactive.png
Sleep 5s

Type "# Fonts were installed in directory:"
Sleep 2s
Enter

Type "ls -lah ${HOME}/.local/share/fonts"
Enter
Wait
Sleep 5s
