# Branches

A Dart application that helps you manage git branches sorted by their last commit date.

## Features

- Lists branches sorted by last commit date
- Highlights the current branch
- Allows checking out branches by index
- Allows deleting branches by index (with safeguards for current branch)
- Allows creating new branches from origin/main

## Installation

1. Clone this repository
2. Run `dart pub get` to install dependencies
3. Run `dart compile exe bin/branches.dart -o branches.exe`
4. Add the compiled executable to your PATH

## Usage

Run in any git repository:

```bash
branches
```

Or specify a directory:

```bash
branches --dir=/path/to/git/repo
```

## Set up as Git Alias

You can set this up as a git alias to replace your existing shell script:

```bash
git config --global alias.branches '!branches'
```

Then you can run:

```bash
git branches
```

## Development

- Run tests with `dart test`
