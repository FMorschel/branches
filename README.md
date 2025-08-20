# Branches CLI Tool

A Dart CLI tool for interactive branch management in version control systems (VCS) like Git and Mercurial.

## Features

- **Directory Selection**
  - Opens in the current directory by default
  - Supports `--dir` or `-d` to specify a target folder
  - Detects known VCS implementations (Git, Mercurial)

- **Branch List Display**
  - Shows a list of branches (configurable length, default: all)
  - Sorting options: by date (default: most recent first/last), alphabetically

- **Output Configuration**
  - Configure which columns are shown: commit hash (configurable length), date, author, Gerrit issue/status

- **Project Configuration**
  - Save and reuse display/output configuration for the project

- **Interactive List Actions**
  - **Selection/Checkout:**
    - Select (checkout) a branch by typing its number
    - Navigate with up/down arrows, select with Enter
  - **Branch Creation:**
    - Type a new branch name to create directly from the list view
  - **Branch Deletion:**
    - Delete by typing `-number` (e.g., `-3`)
    - Or select with arrows and press Backspace (with confirmation)
  - **Branch Renaming:**
    - Select with arrows and press `>` to rename
  - **Next/Previous Page:**
    - Use left/right arrows to change pages when length is defined
  - All actions provide clear feedback and confirmation for destructive operations

## Installation

1. Clone this repository
2. Run `dart pub get` to install dependencies
3. Run `dart compile exe bin/branches.dart -o branches.exe`
4. Add the compiled executable to your PATH

## Usage

Run in any VCS repository:

```bash
branches
```

Or specify a directory:

```bash
branches --dir=/path/to/git/repo
```

## Set up as Git Alias

You can set this up as a git alias:

```bash
git config --global alias.branches '!branches'
```

Then run:

```bash
git branches
```

## Development

- Run tests with `dart test`
