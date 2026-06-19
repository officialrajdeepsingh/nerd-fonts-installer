<h1 style="text-align: center;">Nerd Fonts Installer</h1>

<div style="display:flex;justify-content:center">

 <img src="https://img.shields.io/github/license/Ileriayo/markdown-badges?style=for-the-badge" alt="Licence" /> 
 <img src="https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white" alt="Debian" /> 
 <img src="https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash Script" />
 <img src="https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell" />
 <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows" />

</div>

---

The Nerd Fonts installer provides cross-platform scripts to easily install Nerd Fonts from the command line. It includes a bash script for Linux and macOS systems, and a PowerShell script for Windows systems.

## Features

### ✨ Cross-Platform Support
- **Linux/macOS**: Bash script (`install.sh`) with user-level font installation
- **Windows (Cygwin)**: Bash script installs to both `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and `~/.local/share/fonts/`
- **Windows 10/11**: PowerShell script (`install.ps1`) with user-level font installation

### 🎯 Easy to Use
- Interactive menu with all 70 Nerd Fonts
- Non-interactive mode for scripting and automation
- Install multiple fonts in one run
- Colored output for better user experience
- Input validation and error handling
- Automatic cleanup of temporary files

### 🔧 Platform-Specific Installation
- **Linux**: Installs to `~/.local/share/fonts/` (or `$XDG_DATA_HOME/fonts/`) and refreshes font cache
- **macOS**: Installs to `~/Library/Fonts/`
- **Windows (Cygwin)**: Installs to both `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and `~/.local/share/fonts/` (or `$XDG_DATA_HOME/fonts/`), and refreshes font cache
- **Windows**: Installs to `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and registers with system

### 📦 Font Support
- Supports both `.ttf` and `.otf` font files
- Downloads latest versions from GitHub releases
- Prefers `.tar.xz` archives (smaller); falls back to `.zip` when `xz` is unavailable
- Handles font extraction and installation automatically

## Compatibility

### Windows Support
- **Windows 10**: Version 1903 (May 2019 Update) or later
- **Windows 11**: All versions supported
- **PowerShell**: 5.1+ or PowerShell Core 6+

The Windows PowerShell script has been tested on:
- Windows 10 Pro for Workstations (Build 26100)
- PowerShell Core 7.5.2
- PowerShell 5.1 (Windows PowerShell)

### Linux/macOS/Cygwin Support
- All modern Linux distributions with Bash 3.2+
- macOS 10.9+ (Mavericks) or later
- Cygwin on Windows 10/11 (requires `curl` or `wget`, `tar` or `unzip`, `cygpath`)

## Demo
![DEMO](/media/install-nerd-font.gif "install nerd font")

## Install Nerd fonts

### Linux, macOS and Cygwin (Bash)

**Interactive mode** — pick fonts from a menu:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh)"
```

**Non-interactive mode** — install one or more fonts directly:

```bash
# Single font
curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh | bash -s -- Monoid

# Multiple fonts (space-separated or comma-separated)
curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh | bash -s -- Monoid Hack JetBrainsMono
curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh | bash -s -- Monoid,Hack,JetBrainsMono
```

**Options:**

| Flag | Env var | Description |
|---|---|---|
| `--quiet` / `-q` | `LOG_LEVEL=0` | Suppress informational output |
| `--color` | `USE_COLOR=1` | Force colored output |
| `--no-color` | `USE_COLOR=0` | Disable colored output |
| — | `NERD_FONTS_VERSION=v3.4.0` | Pin a specific release |

```bash
# Pin a version
NERD_FONTS_VERSION=v3.4.0 bash install.sh Monoid

# Silent install
bash install.sh --quiet Monoid
```

### Windows (PowerShell)
For Windows users, use the PowerShell version of the installer.

**Requirements:**
- Windows 10 (version 1903 or later) or Windows 11
- PowerShell 5.1+ or PowerShell Core 6+

```powershell
# Run in PowerShell (requires PowerShell Core 6+ or Windows PowerShell 5.1+)
iex "& { $(iwr -useb 'https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.ps1') }"
```

Or download and run locally:
```powershell
# Download the script
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.ps1' -OutFile 'install.ps1'

# Run the script
.\install.ps1
```

After selecting your nerd font, it starts downloading into the system. The PowerShell version installs fonts to the user's local fonts directory and attempts to register them with Windows.
