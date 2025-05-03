# Combr

A macOS utility for browsing and extracting code from your projects. Combr makes it easy to select multiple files across your codebase and combine their contents into a single formatted output for use with AI tools.

# Demo

<div align="center">


</div>

## Features

- File browser with checkboxes for easy selection
- Automatic file filtering based on file extensions
- Custom text options for output formatting
- One-click clipboard copying
- Keyboard shortcuts for navigation

## Installation

```bash
git clone https://github.com/yourusername/combr.git
cd combr
swift build -c release
```

The executable will be at `.build/release/combr`. Move it to your PATH:

```bash
cp .build/release/combr /usr/local/bin/
```

## Usage

Run in the directory you want to browse:

```bash
combr [options]
```

### Options

- `--ext=<extension>`: Specify file extensions to auto-select
- `--exclude=<pattern>`: Pattern to exclude (wildcard matching)
- `--include=<pattern>`: Pattern to force include (wildcard matching)
- `--help, -h`: Show help

### Keyboard Shortcuts

- `Enter`: Confirm and copy to clipboard
- `Esc`: Close the window
- `Space`: Toggle selection of highlighted item
- `Up/Down Arrow`: Navigate the file list

## Building from Source

Prerequisites:
- Xcode 12+ or Swift 5.3+
- macOS 10.14+

Steps:
1. Clone the repository
2. Run `swift build` to build
3. Run `swift run` to run