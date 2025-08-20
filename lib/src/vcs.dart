import 'dart:async';
import 'dart:io';

import 'project.dart';
import 'vcs_member.dart';

sealed class Vcs {
  Vcs._(this.project);

  final Project project;

  factory Vcs.at(Project project) {
    // Detect the version control system
    if (Git.isValidRepository(project.path)) {
      return Git(project);
    }
    throw Exception('Unsupported VCS');
  }

  Future<void> updateBranches();

  Future<void> createBranch({required String branchName, Branch? baseBranch});

  Future<Branch> getBranch({required String branchName});

  Future<void> deleteBranch({required String branchName});

  Future<void> renameBranch({required String oldName, required String newName});

  Future<void> checkoutBranch({required String branchName});
}

class Git extends Vcs {
  Git(super.project) : super._();

  static const String _dataFormat =
      '--format=%(refname:short)'
      '|%(objectname:short)|%(committerdate:iso8601)'
      '|%(subject)|%(authorname)|%(authoremail)';

  static bool isValidRepository(String path) {
    try {
      // Use git rev-parse to check if the directory is a valid git repository
      final result = Process.runSync('git', [
        'rev-parse',
        '--git-dir',
      ], workingDirectory: path);

      // If exit code is 0, it's a valid git repository
      return result.exitCode == 0;
    } catch (e) {
      // If any exception occurs (git not found, etc.), return false
      return false;
    }
  }

  @override
  Future<void> updateBranches() async {
    try {
      // Clear existing branches
      project.clearBranches();

      // Get all branches with their last commit info
      final result = await Process.run('git', [
        'for-each-ref',
        _dataFormat,
        'refs/heads/',
      ], workingDirectory: project.path);

      if (result.exitCode != 0) {
        throw Exception('Git command failed: ${result.stderr}');
      }

      final output = result.stdout as String;
      final lines = output.trim().split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final parts = line.split('|');
        if (parts.length != 6) continue;

        final branchName = parts[0];
        final commitId = parts[1];
        final dateString = parts[2];
        final message = parts[3];
        final authorName = parts[4];
        final authorEmail = parts[5];

        // Parse the date
        final date = DateTime.parse(dateString);

        // Create model instances
        final author = Author(name: authorName, email: authorEmail);

        final commit = Commit(
          id: commitId,
          message: message,
          date: date,
          author: author,
        );

        final branch = Branch(name: branchName, lastCommit: commit);

        project.addBranch(branch);
      }
    } catch (e) {
      throw Exception('Failed to update branches: $e');
    }
  }

  @override
  Future<void> createBranch({
    required String branchName,
    Branch? baseBranch,
  }) async {
    try {
      final process = await Process.run('git', [
        'checkout',
        '-b',
        branchName,
        ?baseBranch?.name,
      ], workingDirectory: project.path);

      if (process.exitCode != 0) {
        throw Exception('Git command failed: ${process.stderr}');
      }

      final branch = await getBranch(branchName: branchName);
      project.addBranch(branch);
    } catch (e) {
      throw Exception('Failed to create branch: $e');
    }
  }

  @override
  Future<Branch> getBranch({required String branchName}) async {
    try {
      // Get branch info with last commit details
      final result = await Process.run('git', [
        'for-each-ref',
        _dataFormat,
        'refs/heads/$branchName',
      ]);

      if (result.exitCode != 0) {
        throw Exception('Git command failed: ${result.stderr}');
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty) {
        throw Exception('Branch "$branchName" not found');
      }

      final parts = output.split('|');
      if (parts.length != 6) {
        throw Exception('Invalid git output format');
      }

      final commitId = parts[1];
      final dateString = parts[2];
      final message = parts[3];
      final authorName = parts[4];
      final authorEmail = parts[5];

      // Parse the date
      final date = DateTime.parse(dateString);

      // Create model instances
      final author = Author(name: authorName, email: authorEmail);

      final commit = Commit(
        id: commitId,
        message: message,
        date: date,
        author: author,
      );

      return Branch(name: branchName, lastCommit: commit);
    } catch (e) {
      throw Exception('Failed to get branch "$branchName": $e');
    }
  }

  @override
  Future<void> deleteBranch({required String branchName}) async {
    try {
      final branch = await getBranch(branchName: branchName);

      final process = await Process.run('git', [
        'branch',
        '-d',
        branchName,
      ], workingDirectory: project.path);

      if (process.exitCode != 0) {
        throw Exception('Git command failed: ${process.stderr}');
      }

      project.removeBranch(branch);
    } catch (e) {
      throw Exception('Failed to delete branch "$branchName": $e');
    }
  }

  @override
  Future<void> renameBranch({
    required String oldName,
    required String newName,
  }) async {
    try {
      // Update the project branches
      final oldBranch = await getBranch(branchName: oldName);

      final process = await Process.run('git', [
        'branch',
        '-m',
        oldName,
        newName,
      ], workingDirectory: project.path);

      if (process.exitCode != 0) {
        throw Exception('Git command failed: ${process.stderr}');
      }

      final newBranch = await getBranch(branchName: newName);

      project.removeBranch(oldBranch);
      project.addBranch(newBranch);
    } catch (e) {
      throw Exception(
        'Failed to rename branch from "$oldName" to "$newName": $e',
      );
    }
  }

  @override
  Future<void> checkoutBranch({required String branchName}) async {
    try {
      final process = await Process.run('git', [
        'checkout',
        branchName,
      ], workingDirectory: project.path);

      if (process.exitCode != 0) {
        throw Exception('Git command failed: ${process.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to checkout branch "$branchName": $e');
    }
  }
}
