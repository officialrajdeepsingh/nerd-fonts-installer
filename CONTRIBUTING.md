# Contributing to Nerd Fonts Installer

First off, thanks for taking the time to contribute!

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Project Structure](#project-structure)
- [Code Structure (install.sh)](#code-structure-installsh)
- [Dependencies](#dependencies)
- [Development Workflow](#development-workflow)
- [How to Contribute](#how-to-contribute)

## Code of Conduct

This project and everyone participating in it is governed by the
[Code of Conduct](https://github.com/officialrajdeepsingh/nerd-fonts-installer/blob/master/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.

## Project Structure

```
nerd-fonts-installer/
├── install.sh            # Core bash installer (all logic)
├── cli                   # Node.js wrapper for npm/npx usage
├── package.json          # npm package metadata + scripts
├── .github/
│   └── workflows/
│       └── publish.yml   # GitHub Actions: publish to npm on tag push
├── media/                #  VHS tape files for generating media (screenshots and demos)
│   ├── screenshot.tape   # for screenshot
│   ├── demo.tape         # for video
│   ├── screenshot-dark.png
│   └── demo-dark.gif
├── .npmignore            # Files excluded from npm publish
├── .gitignore
├── LICENSE
├── README.MD
└── CONTRIBUTING.MD
```

## Code Structure (install.sh)

The main script (`install.sh`) is organized into logical sections with clear headers:

| Section | Lines | Purpose |
|---|---|---|
| **Configuration** | 10-17 | Version, log prefix, log level |
| **Logging & Output** | 21-40 | Color setup, log functions (`log_info`, `log_success`, `log_error`) |
| **Helpers** | 44-68 | `command_exists`, `to_lower`, `tar_has_xz_support`, `tool_require_first` |
| **Font Selection** | 72-129 | `font_resolve`, `font_search`, `font_add`, `font_remove` — manage the install queue |
| **System Detection** | 133-200 | `font_dir_detect`, `preflight_check` — detect OS, tools, font directories |
| **Installed Font Detection** | 204-236 | `font_detect_installed`, `font_detect_installed_all` — find already-installed fonts |
| **Interactive Mode** | 240-370 | `font_menu_show`, `font_select_interactive` — the font selection menu and input loop |
| **Non-Interactive & Update** | 374-397 | `font_select_noninteractive`, `font_select_update` — CLI args and update mode |
| **Download & Install** | 401-470 | `file_download`, `archive_extract`, `font_download`, `font_install`, `font_register_windows`, `font_cache_rebuild`, `font_install_all` |
| **Output** | 474-533 | `greeting`, `help_show` — startup message and help text |
| **Font List Data** | 537-610 | `font_list_set` — the 70 available Nerd Fonts |
| **Main Entry Point** | 614-672 | `main()` — argument parsing, routing, cleanup |

### Execution Flow

1. `main()` parses CLI flags (`--version`, `--quiet`, `--color`, `--nerd-fonts-version`)
2. Sets up colors and prints the greeting
3. Runs `preflight_check()` to detect OS, tools, and font directories
4. Routes to the appropriate mode:
   - **Interactive**: `font_select_interactive()` — shows menu, user selects fonts, then installs
   - **Non-interactive**: `font_select_noninteractive()` — parses font names from arguments
   - **Update**: `font_select_update()` — detects and reinstalls installed fonts
   - **List**: `font_detect_installed()` — shows currently installed fonts
5. `font_install_all()` downloads, extracts, and installs each font

## Dependencies

**Zero runtime dependencies.** The installer is a single bash script. It requires only:

- **bash** 3.2+ (or Git Bash on Windows)
- **curl** or **wget** — for downloading font archives
- **tar** or **unzip** — for extracting archives
  - `tar` with `xz` support is preferred (smaller downloads)
  - Falls back to `unzip` when `xz` is unavailable
- **PowerShell** (Windows/Cygwin only) — for registering fonts with the system

For npm users, the `cli` wrapper (Node.js) locates bash and forwards all arguments.
It is not required when running `install.sh` directly.

## Development Workflow

### Running the script locally

```bash
# Interactive mode
./install.sh

# List installed fonts
./install.sh --list

# Install specific fonts
./install.sh Hack FiraCode

# Pin a specific Nerd Fonts release
./install.sh --nerd-fonts-version=v3.4.0 Hack
```

### Testing changes

This is a bash script — no test framework is needed for basic validation.
To test your changes:

1. Run `./install.sh --version` to verify it starts
2. Run `./install.sh --help` to verify the help text
3. Run `./install.sh --list` to verify font detection
4. Install a font you don't need with `./install.sh <font-name>`

### Code style

- Follow the existing section structure with `# ====== SECTION NAME ======` headers
- Use 4-space indentation
- Keep functions focused on a single responsibility
- Use `local` for all variables inside functions
- Use `readonly` for constants
- Add comments for non-obvious logic
- Run `shellcheck install.sh` to catch common issues

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Make your changes
4. Run `shellcheck install.sh` to check for issues
5. Run `npm run screenshot` to genrate the screenshort/video (demo) for project
6. Commit and push your branch
7. Open a Pull Request

### What needs help

- Adding new Nerd Fonts to the `font_list_set()` array
- Improving cross-platform support (especially macOS detection)
- Better error messages and edge case handling
- Documentation improvements
