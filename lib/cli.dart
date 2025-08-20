import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';

import 'src/command.dart';
import 'src/project.dart';
import 'src/vcs_member.dart';

/// Configuration for CLI display options
class CliConfig {
  CliConfig({
    this.commitHashLength = 7,
    this.showDate = true,
    this.showAuthor = true,
    this.showCommitHash = true,
    this.showGerritInfo = false,
    this.sortByDate = true,
    this.sortAscending = false,
    this.pageSize,
  });

  final int commitHashLength;
  final bool showDate;
  final bool showAuthor;
  final bool showCommitHash;
  final bool showGerritInfo;
  final bool sortByDate;
  final bool sortAscending;
  final int? pageSize;

  CliConfig copyWith({
    int? commitHashLength,
    bool? showDate,
    bool? showAuthor,
    bool? showCommitHash,
    bool? showGerritInfo,
    bool? sortByDate,
    bool? sortAscending,
    int? pageSize,
  }) {
    return CliConfig(
      commitHashLength: commitHashLength ?? this.commitHashLength,
      showDate: showDate ?? this.showDate,
      showAuthor: showAuthor ?? this.showAuthor,
      showCommitHash: showCommitHash ?? this.showCommitHash,
      showGerritInfo: showGerritInfo ?? this.showGerritInfo,
      sortByDate: sortByDate ?? this.sortByDate,
      sortAscending: sortAscending ?? this.sortAscending,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Interactive CLI for branch management
class BranchesCli {
  BranchesCli({required this.project, CliConfig? config})
    : _config = config ?? CliConfig(),
      _console = Console();

  final Project project;
  final Console _console;
  final CliConfig _config;
  int _currentPage = 0;

  /// Start the interactive CLI session
  Future<void> run() async {
    _console.clearScreen();
    _showHeader();

    // Wait for initial branch loading
    try {
      await project.waitAllCommands();
    } catch (e, s) {
      print('$e\n$s');
    }

    while (true) {
      _displayBranches();
      _showInstructions();

      final input = await _getInput();
      if (input == null) break;

      final action = _parseInput(input);
      if (action == null) continue;

      final shouldExit = await _executeAction(action);
      if (shouldExit) break;
    }
  }

  void _showHeader() {
    _console.writeLine('=== Branches CLI Tool ===');
    _console.writeLine('Directory: ${project.path}');
    _console.writeLine('VCS: ${project.vcs.runtimeType}');
    _console.writeLine('');
  }

  void _displayBranches() {
    final branches = _getSortedBranches();
    final pagedBranches = _getPagedBranches(branches);

    _console.clearScreen();
    _showHeader();

    if (branches.isEmpty) {
      _console.writeLine('No branches found.');
      return;
    }

    // Show page info if pagination is enabled
    if (_config.pageSize != null) {
      final totalPages = (branches.length / _config.pageSize!).ceil();
      _console.writeLine('Page ${_currentPage + 1} of $totalPages');
      _console.writeLine('');
    }

    // Display header
    _displayHeader();

    // Display branches
    for (int i = 0; i < pagedBranches.length; i++) {
      final globalIndex =
          _currentPage * (_config.pageSize ?? branches.length) + i + 1;
      _displayBranch(globalIndex, pagedBranches[i]);
    }

    _console.writeLine('');
  }

  void _displayHeader() {
    final headers = <String>['#', 'Branch'];

    if (_config.showCommitHash) headers.add('Hash');
    if (_config.showDate) headers.add('Date');
    if (_config.showAuthor) headers.add('Author');
    if (_config.showGerritInfo) headers.add('Gerrit');

    _console.writeLine(headers.join('\t'));
    _console.writeLine('-' * 80);
  }

  void _displayBranch(int index, Branch branch) {
    final parts = <String>[index.toString(), branch.name];

    if (_config.showCommitHash) {
      parts.add(branch.lastCommit.shortId(length: _config.commitHashLength));
    }

    if (_config.showDate) {
      parts.add(_formatDate(branch.lastCommit.date));
    }

    if (_config.showAuthor) {
      parts.add(branch.lastCommit.author.name);
    }

    if (_config.showGerritInfo) {
      if (project.gerritHandler case var handler?) {
        final gerritInfo = handler.getInfo(branch.lastCommit);
        parts.add(gerritInfo ?? '-');
      } else {
        parts.add('-');
      }
    }

    _console.writeLine(parts.join('\t'));
  }

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  List<Branch> _getSortedBranches() {
    final branches = List<Branch>.from(project.branches);

    if (_config.sortByDate) {
      branches.sort((a, b) {
        final comparison = a.lastCommit.date.compareTo(b.lastCommit.date);
        return _config.sortAscending ? comparison : -comparison;
      });
    } else {
      branches.sort((a, b) {
        final comparison = a.name.compareTo(b.name);
        return _config.sortAscending ? comparison : -comparison;
      });
    }

    return branches;
  }

  List<Branch> _getPagedBranches(List<Branch> branches) {
    if (_config.pageSize == null) return branches;

    final startIndex = _currentPage * _config.pageSize!;
    final endIndex = (startIndex + _config.pageSize!).clamp(0, branches.length);

    return branches.sublist(startIndex, endIndex);
  }

  void _showInstructions() {
    _console.writeLine('Commands:');
    _console.writeLine('  [number] - Checkout branch');
    _console.writeLine('  -[number] - Delete branch');
    _console.writeLine('  [name] - Create new branch');
    _console.writeLine('  > [number] [new_name] - Rename branch');
    if (_config.pageSize != null) {
      _console.writeLine('  < / > - Previous/Next page');
    }
    _console.writeLine('  q - Quit');
    _console.write('> ');
  }

  Future<String?> _getInput() async {
    final key = _console.readKey();

    // Handle special keys
    if (key.isControl) {
      switch (key.controlChar) {
        case ControlCharacter.ctrlC:
        case ControlCharacter.escape:
          return null;
        case ControlCharacter.arrowLeft:
          if (_config.pageSize != null && _currentPage > 0) {
            _currentPage--;
            return '';
          }
          break;
        case ControlCharacter.arrowRight:
          if (_config.pageSize != null) {
            final maxPage =
                (project.branches.length / _config.pageSize!).ceil() - 1;
            if (_currentPage < maxPage) {
              _currentPage++;
              return '';
            }
          }
          break;
        case ControlCharacter.none:
        default:
          break;
      }
      return '';
    }

    // Read full line for text input
    _console.write(key.char);
    final line = stdin.readLineSync();
    return key.char + (line ?? '');
  }

  CliAction? _parseInput(String input) {
    final trimmed = input.trim();

    if (trimmed.isEmpty) return null;
    if (trimmed == 'q' || trimmed == 'quit') {
      return ExitAction();
    }

    // Page navigation
    if (trimmed == '<' && _currentPage > 0) {
      _currentPage--;
      return RefreshAction();
    }
    if (trimmed == '>') {
      final maxPage = _config.pageSize != null
          ? (project.branches.length / _config.pageSize!).ceil() - 1
          : 0;
      if (_currentPage < maxPage) {
        _currentPage++;
      }
      return RefreshAction();
    }

    // Delete branch
    if (trimmed.startsWith('-')) {
      final numberStr = trimmed.substring(1);
      final number = int.tryParse(numberStr);
      if (number != null) {
        return DeleteBranchAction(branchIndex: number - 1);
      }
    }

    // Rename branch
    if (trimmed.startsWith('>')) {
      final parts = trimmed.substring(1).trim().split(' ');
      if (parts.length >= 2) {
        final number = int.tryParse(parts[0]);
        if (number != null) {
          return RenameBranchAction(
            branchIndex: number - 1,
            newName: parts.sublist(1).join(' '),
          );
        }
      }
    }

    // Checkout branch by number
    final number = int.tryParse(trimmed);
    if (number != null) {
      return CheckoutBranchAction(branchIndex: number - 1);
    }

    // Create new branch
    if (trimmed.isNotEmpty && !trimmed.contains(' ')) {
      return CreateBranchAction(branchName: trimmed);
    }

    return null;
  }

  Future<bool> _executeAction(CliAction action) async {
    try {
      switch (action) {
        case ExitAction():
          return true;
        case RefreshAction():
          return false;
        case CheckoutBranchAction():
          await _checkoutBranch(action.branchIndex);
        case CreateBranchAction():
          await _createBranch(action.branchName);
        case DeleteBranchAction():
          await _deleteBranch(action.branchIndex);
        case RenameBranchAction():
          await _renameBranch(action.branchIndex, action.newName);
      }
    } catch (e) {
      _console.writeLine('Error: $e');
      _console.writeLine('Press any key to continue...');
      _console.readKey();
    }
    return false;
  }

  Future<void> _checkoutBranch(int index) async {
    final branches = _getSortedBranches();
    final globalIndex =
        _currentPage * (_config.pageSize ?? branches.length) + index;

    if (globalIndex >= 0 && globalIndex < branches.length) {
      final branch = branches[globalIndex];
      _console.writeLine('Checking out branch: ${branch.name}');

      try {
        await project.execute(
          CheckoutBranchCommand(
            versionControlSystem: project.vcs,
            branchName: branch.name,
          ),
        );
        await project.waitAllCommands();
        _console.writeLine('Successfully checked out branch: ${branch.name}');
      } catch (e) {
        _console.writeLine('Failed to checkout branch: $e');
      }

      _console.writeLine('Press any key to continue...');
      _console.readKey();
    } else {
      _console.writeLine('Invalid branch number');
      _console.writeLine('Press any key to continue...');
      _console.readKey();
    }
  }

  Future<void> _createBranch(String branchName) async {
    _console.writeLine('Creating branch: $branchName');

    try {
      await project.execute(
        CreateNewBranchCommand(
          versionControlSystem: project.vcs,
          branchName: branchName,
        ),
      );
      await project.waitAllCommands();

      // Refresh branches
      await project.execute(
        GetBranchesCommand(project: project, versionControlSystem: project.vcs),
      );
      await project.waitAllCommands();

      _console.writeLine('Successfully created branch: $branchName');
    } catch (e) {
      _console.writeLine('Failed to create branch: $e');
    }

    _console.writeLine('Press any key to continue...');
    _console.readKey();
  }

  Future<void> _deleteBranch(int index) async {
    final branches = _getSortedBranches();
    final globalIndex =
        _currentPage * (_config.pageSize ?? branches.length) + index;

    if (globalIndex >= 0 && globalIndex < branches.length) {
      final branch = branches[globalIndex];
      _console.write('Delete branch "${branch.name}"? (y/N): ');
      final confirmation = stdin.readLineSync()?.toLowerCase();

      if (confirmation == 'y' || confirmation == 'yes') {
        _console.writeLine('Deleting branch: ${branch.name}');

        try {
          await project.execute(
            DeleteBranchCommand(
              versionControlSystem: project.vcs,
              branchName: branch.name,
            ),
          );
          await project.waitAllCommands();

          // Refresh branches
          await project.execute(
            GetBranchesCommand(
              project: project,
              versionControlSystem: project.vcs,
            ),
          );
          await project.waitAllCommands();

          _console.writeLine('Successfully deleted branch: ${branch.name}');
        } catch (e) {
          _console.writeLine('Failed to delete branch: $e');
        }
      } else {
        _console.writeLine('Deletion cancelled');
      }
    } else {
      _console.writeLine('Invalid branch number');
    }
    _console.writeLine('Press any key to continue...');
    _console.readKey();
  }

  Future<void> _renameBranch(int index, String newName) async {
    final branches = _getSortedBranches();
    final globalIndex =
        _currentPage * (_config.pageSize ?? branches.length) + index;

    if (globalIndex >= 0 && globalIndex < branches.length) {
      final branch = branches[globalIndex];
      _console.writeLine('Renaming branch "${branch.name}" to "$newName"');

      try {
        await project.execute(
          RenameBranchCommand(
            versionControlSystem: project.vcs,
            oldName: branch.name,
            newName: newName,
          ),
        );
        await project.waitAllCommands();

        // Refresh branches
        await project.execute(
          GetBranchesCommand(
            project: project,
            versionControlSystem: project.vcs,
          ),
        );
        await project.waitAllCommands();

        _console.writeLine('Successfully renamed branch to: $newName');
      } catch (e) {
        _console.writeLine('Failed to rename branch: $e');
      }
    } else {
      _console.writeLine('Invalid branch number');
    }
    _console.writeLine('Press any key to continue...');
    _console.readKey();
  }
}

/// Base class for CLI actions
sealed class CliAction {}

class ExitAction extends CliAction {}

class RefreshAction extends CliAction {}

class CheckoutBranchAction extends CliAction {
  CheckoutBranchAction({required this.branchIndex});
  final int branchIndex;
}

class CreateBranchAction extends CliAction {
  CreateBranchAction({required this.branchName});
  final String branchName;
}

class DeleteBranchAction extends CliAction {
  DeleteBranchAction({required this.branchIndex});
  final int branchIndex;
}

class RenameBranchAction extends CliAction {
  RenameBranchAction({required this.branchIndex, required this.newName});
  final int branchIndex;
  final String newName;
}
