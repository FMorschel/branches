import 'dart:io';

import 'package:args/args.dart';
import 'package:branches/cli.dart';
import 'package:branches/src/project.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'dir',
      abbr: 'd',
      help: 'Git repository directory to use',
      defaultsTo: Directory.current.path,
    )
    ..addOption('page-size', help: 'Number of branches to show per page')
    ..addFlag(
      'sort-alpha',
      help: 'Sort branches alphabetically instead of by date',
      negatable: false,
    )
    ..addFlag(
      'sort-asc',
      help: 'Sort in ascending order (default is descending)',
      negatable: false,
    )
    ..addOption(
      'hash-length',
      help: 'Length of commit hash to display',
      defaultsTo: '7',
    )
    ..addFlag(
      'date',
      help: 'Show date column',
      negatable: true,
      defaultsTo: true,
    )
    ..addFlag(
      'author',
      help: 'Show author column',
      negatable: true,
      defaultsTo: true,
    )
    ..addFlag(
      'hash',
      help: 'Show commit hash column',
      negatable: true,
      defaultsTo: true,
    )
    ..addFlag(
      'show-gerrit',
      help: 'Show Gerrit information',
      negatable: true,
      defaultsTo: true,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false,
    );

  try {
    final argResults = parser.parse(arguments);

    if (argResults['help'] as bool) {
      stdout.writeln('Branches CLI Tool - Interactive VCS branch management');
      stdout.writeln('');
      stdout.writeln('Usage: branches [options]');
      stdout.writeln('');
      stdout.writeln(parser.usage);
      stdout.writeln('');
      stdout.writeln('Interactive Commands:');
      stdout.writeln('  [number]              - Checkout branch by number');
      stdout.writeln('  -[number]             - Delete branch by number');
      stdout.writeln('  [branch_name]         - Create new branch');
      stdout.writeln('  > [number] [new_name] - Rename branch');
      stdout.writeln(
        '  < / >                 - Previous/Next page (if pagination enabled)',
      );
      stdout.writeln('  q                     - Quit');
      return;
    }

    final workingDir = argResults['dir'] as String;

    // Validate directory exists
    final directory = Directory(workingDir);
    if (!directory.existsSync()) {
      stderr.writeln('Error: Directory "$workingDir" does not exist');
      exitCode = 1;
      return;
    }

    // Parse configuration from arguments
    final pageSize = argResults['page-size'] != null
        ? int.tryParse(argResults['page-size'] as String)
        : null;

    final hashLength = int.tryParse(argResults['hash-length'] as String) ?? 7;

    final config = CliConfig(
      pageSize: pageSize,
      sortByDate: argResults['sort-alpha'] as bool,
      sortAscending: argResults['sort-asc'] as bool,
      commitHashLength: hashLength,
      showDate: argResults['date'] as bool,
      showAuthor: argResults['author'] as bool,
      showCommitHash: argResults['hash'] as bool,
      showGerritInfo: argResults['show-gerrit'] as bool,
    );

    // Initialize project and CLI
    final project = Project(path: workingDir);
    final cli = BranchesCli(project: project, config: config);

    // Run the interactive CLI
    await cli.run();
  } catch (e) {
    stderr.writeln('Error: $e');
    stderr.writeln('Usage: branches [options]');
    stderr.writeln(parser.usage);
    exitCode = 1;
  }
}
