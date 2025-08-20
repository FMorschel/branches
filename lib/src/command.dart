import 'dart:async';

import 'package:async/async.dart';

import 'project.dart';
import 'vcs.dart';
import 'vcs_member.dart';

sealed class Command<T> {
  Command();

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  Completer<Result<T>> result = Completer<Result<T>>();

  FutureOr<void> execute();

  Future<T> run() async {
    await execute();
    final result = await this.result.future;
    return switch (result.asValue) {
      Result(:var isValue, :var asValue) when isValue => asValue?.value,
      _ => () {
        final error = result.asError;
        throw Exception(
          'Failed to execute command ${error?.error}\n${error?.stackTrace}',
        );
      }(),
    };
  }
}

class GetBranchesCommand extends Command<void> {
  GetBranchesCommand({
    required this.project,
    required this.versionControlSystem,
  });

  final Project project;
  final Vcs versionControlSystem;

  @override
  Future<void> execute() async {
    _isRunning = true;
    try {
      await versionControlSystem.updateBranches();
      result.complete(Result.value(null));
    } finally {
      _isRunning = false;
    }
  }
}

class CreateNewBranchCommand extends Command<void> {
  CreateNewBranchCommand({
    required this.versionControlSystem,
    required this.branchName,
    this.baseBranch,
  });

  final Vcs versionControlSystem;
  final String branchName;
  final Branch? baseBranch;

  @override
  Future<void> execute() async {
    _isRunning = true;
    try {
      await versionControlSystem.createBranch(
        branchName: branchName,
        baseBranch: baseBranch,
      );
      result.complete(Result.value(null));
    } finally {
      _isRunning = false;
    }
  }
}

class DeleteBranchCommand extends Command<void> {
  DeleteBranchCommand({
    required this.versionControlSystem,
    required this.branchName,
  });

  final Vcs versionControlSystem;
  final String branchName;

  @override
  Future<void> execute() async {
    _isRunning = true;
    try {
      await versionControlSystem.deleteBranch(branchName: branchName);
      result.complete(Result.value(null));
    } finally {
      _isRunning = false;
    }
  }
}

class CheckoutBranchCommand extends Command<void> {
  CheckoutBranchCommand({
    required this.versionControlSystem,
    required this.branchName,
  });

  final Vcs versionControlSystem;
  final String branchName;

  @override
  Future<void> execute() async {
    _isRunning = true;
    try {
      await versionControlSystem.checkoutBranch(branchName: branchName);
      result.complete(Result.value(null));
    } finally {
      _isRunning = false;
    }
  }
}

class RenameBranchCommand extends Command<void> {
  RenameBranchCommand({
    required this.versionControlSystem,
    required this.oldName,
    required this.newName,
  });

  final Vcs versionControlSystem;
  final String oldName;
  final String newName;

  @override
  Future<void> execute() async {
    _isRunning = true;
    try {
      await versionControlSystem.renameBranch(
        oldName: oldName,
        newName: newName,
      );
      result.complete(Result.value(null));
    } finally {
      _isRunning = false;
    }
  }
}
