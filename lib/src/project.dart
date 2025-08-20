import 'dart:async';

import 'command.dart';
import 'command_queue.dart';
import 'gerrit_handler.dart';
import 'vcs.dart';
import 'vcs_member.dart';

class Project {
  Project({required this.path}) : _commandQueue = CommandQueue() {
    vcs = Vcs.at(this);
    gerritHandler = GerritHandler.to(this);
    unawaited(
      execute(GetBranchesCommand(project: this, versionControlSystem: vcs)),
    );
  }

  final String path;

  late final Vcs vcs;
  late final GerritHandler? gerritHandler;

  final CommandQueue<void> _commandQueue;

  bool get isRunningCommand => _commandQueue.isRunning;
  Future<void> waitAllCommands() async {
    return await _commandQueue.waitAll();
  }

  final _branches = <Branch>[];
  List<Branch> get branches => List.unmodifiable(_branches);

  void addBranch(Branch branch) {
    _branches.add(branch);
  }

  void removeBranch(Branch branch) {
    _branches.remove(branch);
  }

  void clearBranches() {
    _branches.clear();
  }

  Future<void> execute(Command command) async {
    await _commandQueue.process(command);
  }
}
