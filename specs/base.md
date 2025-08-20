# Branches CLI Tool Specification

This CLI tool should provide an interactive interface for managing branches in a version control system (VCS). The following features and behaviors are required:

## Directory Selection

- The tool should open in the current directory by default.
- It should accept a `--dir` or `-d` option to specify a target folder.
- Upon entering a directory, the tool should detect known VCS implementations (e.g., Git, Mercurial).

## Branch List Display

- When a VCS is detected, the tool should display a list of branches (configurable length, default all).
- The list should support sorting options:
  - By date (most recent first or last - default)
  - Alphabetically

## Output Configuration

- Users should be able to configure which data columns are shown in the branch list, including:
  - Commit hash (with configurable length)
  - Date
  - Author
  - Gerrit issue (if applicable)
  - Gerrit status (if applicable - open/closed/conflict)

## Project Configuration

- The tool should allow saving the current display and output configuration for the project, so it can be reused or displayed elsewhere.

## Interactive List Actions

When displaying the branch list, the following interactions should be supported:

- **Selection/Checkout:**
  - Select (checkout) a branch by typing its number in the list.
  - Navigate the list using up/down arrow keys and select (checkout) with return/enter.

- **Branch Creation:**
  - Allow the user to type a new branch name to create a branch directly from the list view.

- **Branch Deletion:**
  - Delete a branch by typing `-number` (e.g., `-3` to delete branch at position 3).
  - Alternatively, use up/down arrows to select a branch and press backspace to request deletion (with confirmation prompt).

- **Branch Renaming:**
  - Use up/down arrows to select a branch and press `>` to initiate renaming.

- **Next/Previous page**
  - Use left/right arrows to go to the next/previous pages when a length has been defined.

All actions should provide clear feedback and request confirmation where destructive operations are involved.
