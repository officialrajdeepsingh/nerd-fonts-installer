#!/usr/bin/env pwsh
# PowerShell Nerd Fonts Installer
# Select and install Nerd Fonts from https://www.nerdfonts.com/font-downloads
# Windows compatible version of install.sh

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to write error messages
function Write-ErrorMessage {
    param([string]$Message)
    Write-ColorOutput "ERROR: $Message" "Red"
}

# Function to write success messages
function Write-SuccessMessage {
    param([string]$Message)
    Write-ColorOutput "SUCCESS: $Message" "Green"
}

# Function to write info messages
function Write-InfoMessage {
    param([string]$Message)
    Write-ColorOutput "INFO: $Message" "Cyan"
}

# Function to clean up temporary files
function Remove-TempFiles {
    param([string]$TempDir)
    try {
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force
            Write-InfoMessage "Cleaned up temporary files"
        }
    }
    catch {
        Write-Host "Warning: Could not clean up temporary files: $_" -ForegroundColor Yellow
    }
}

# Function to register fonts with Windows (best effort)
function Register-WindowsFonts {
    param([string]$FontsPath)
    
    try {
        # Get all font files (.ttf and .otf)
        $FontFiles = Get-ChildItem -Path $FontsPath -Include "*.ttf", "*.otf" -Recurse
        
        if ($FontFiles.Count -eq 0) {
            Write-Host "Warning: No font files found to register" -ForegroundColor Yellow
            return
        }

        Write-InfoMessage "Attempting to register $($FontFiles.Count) font file(s) with Windows..."
        
        # Try to use Windows Shell COM object to install fonts
        $Shell = New-Object -ComObject Shell.Application
        $FontsFolder = $Shell.Namespace(0x14)  # Fonts folder
        
        foreach ($FontFile in $FontFiles) {
            try {
                $FontsFolder.CopyHere($FontFile.FullName, 0x10)  # 0x10 = overwrite existing
            }
            catch {
                # Silent fail for individual font registration
            }
        }
        
        Write-SuccessMessage "Font registration completed"
    }
    catch {
        Write-Host "Warning: Could not register fonts with Windows system: $_" -ForegroundColor Yellow
        Write-InfoMessage "Fonts are still installed in user directory and should work in most applications"
    }
}

# Main script starts here
try {
    Write-ColorOutput "[-] Download The Nerd fonts [-]" "Magenta"
    Write-ColorOutput "#######################" "Magenta"
    Write-ColorOutput "Select Nerd Font" "Yellow"
    
    # Font list - exact same as bash script
    $FontsList = @(
        "Agave", "AnonymousPro", "Arimo", "AurulentSansMono", "BigBlueTerminal", 
        "BitstreamVeraSansMono", "CascadiaCode", "CodeNewRoman", "ComicShannsMono", 
        "Cousine", "DaddyTimeMono", "DejaVuSansMono", "FantasqueSansMono", "FiraCode", 
        "FiraMono", "Gohu", "Go-Mono", "Hack", "Hasklig", "HeavyData", "Hermit", 
        "iA-Writer", "IBMPlexMono", "InconsolataGo", "InconsolataLGC", "Inconsolata", 
        "IosevkaTerm", "JetBrainsMono", "Lekton", "LiberationMono", "Lilex", "Meslo", 
        "Monofur", "Monoid", "Mononoki", "MPlus", "NerdFontsSymbolsOnly", "Noto", 
        "OpenDyslexic", "Overpass", "ProFont", "ProggyClean", "RobotoMono", 
        "ShareTechMono", "SourceCodePro", "SpaceMono", "Terminus", "Tinos", 
        "UbuntuMono", "Ubuntu", "VictorMono"
    )
    
    # Display menu in columns like bash version
    $ColumnCount = 4
    $TotalFonts = $FontsList.Count
    $RowCount = [Math]::Ceiling($TotalFonts / $ColumnCount)
    
    for ($row = 0; $row -lt $RowCount; $row++) {
        $line = ""
        for ($col = 0; $col -lt $ColumnCount; $col++) {
            $index = $row + ($col * $RowCount)
            if ($index -lt $TotalFonts) {
                $number = $index + 1
                $fontName = $FontsList[$index]
                $line += "{0,3}) {1,-20}" -f $number, $fontName
            }
        }
        Write-Host $line
    }
    
    # Add Quit option
    Write-Host ("{0,3}) {1}" -f ($TotalFonts + 1), "Quit")
    Write-Host ""
    
    # Get user selection
    while ($true) {
        $Selection = Read-Host "Enter a number"
        
        # Validate input
        if ($Selection -match '^\d+$') {
            $Number = [int]$Selection
            if ($Number -ge 1 -and $Number -le $TotalFonts) {
                $SelectedFont = $FontsList[$Number - 1]
                break
            }
            elseif ($Number -eq ($TotalFonts + 1)) {
                Write-InfoMessage "Exiting..."
                exit 0
            }
        }
        
        Write-ErrorMessage "Please enter a valid number (1-$($TotalFonts + 1))"
    }
    
    Write-InfoMessage "Starting download $SelectedFont nerd font"
    
    # Set up paths
    $UserFontsPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $TempDir = Join-Path $env:TEMP "NerdFonts_$(Get-Random)"
    $ZipPath = Join-Path $TempDir "$SelectedFont.zip"
    $ExtractPath = Join-Path $TempDir $SelectedFont
    
    # Create directories
    try {
        if (-not (Test-Path $UserFontsPath)) {
            New-Item -Path $UserFontsPath -ItemType Directory -Force | Out-Null
            Write-InfoMessage "Created fonts folder: $UserFontsPath"
        }
        
        New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
        Write-InfoMessage "Created temporary folder: $TempDir"
    }
    catch {
        Write-ErrorMessage "Failed to create directories: $_"
        exit 1
    }
    
    # Download font
    $DownloadUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$SelectedFont.zip"
    Write-InfoMessage "Downloading from: $DownloadUrl"
    
    try {
        # Use Invoke-WebRequest with progress
        $ProgressPreference = 'Continue'
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
        Write-SuccessMessage "Downloaded $SelectedFont.zip"
    }
    catch {
        Write-ErrorMessage "Failed to download font: $_"
        Remove-TempFiles -TempDir $TempDir
        exit 1
    }
    
    # Extract font
    Write-InfoMessage "Extracting $SelectedFont.zip"
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        Write-SuccessMessage "Extracted font files"
    }
    catch {
        Write-ErrorMessage "Failed to extract font: $_"
        Remove-TempFiles -TempDir $TempDir
        exit 1
    }
    
    # Install fonts to user directory
    Write-InfoMessage "Installing fonts to $UserFontsPath"
    try {
        $FontFiles = Get-ChildItem -Path $ExtractPath -Include "*.ttf", "*.otf" -Recurse
        
        if ($FontFiles.Count -eq 0) {
            Write-ErrorMessage "No font files found in the extracted archive"
            Remove-TempFiles -TempDir $TempDir
            exit 1
        }
        
        $InstalledCount = 0
        foreach ($FontFile in $FontFiles) {
            $DestinationPath = Join-Path $UserFontsPath $FontFile.Name
            Copy-Item -Path $FontFile.FullName -Destination $DestinationPath -Force
            $InstalledCount++
        }
        
        Write-SuccessMessage "Installed $InstalledCount font file(s)"
    }
    catch {
        Write-ErrorMessage "Failed to install fonts: $_"
        Remove-TempFiles -TempDir $TempDir
        exit 1
    }
    
    # Try to register fonts with Windows system
    Register-WindowsFonts -FontsPath $ExtractPath
    
    # Clean up temporary files
    Remove-TempFiles -TempDir $TempDir
    
    Write-SuccessMessage "Font installation completed!"
    Write-InfoMessage "Fonts installed to: $UserFontsPath"
    Write-InfoMessage "You may need to restart applications to see the new fonts."
}
catch {
    Write-ErrorMessage "An unexpected error occurred: $_"
    
    # Clean up on error
    if ($TempDir -and (Test-Path $TempDir)) {
        Remove-TempFiles -TempDir $TempDir
    }
    
    exit 1
}