// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'project.dart';
import 'vcs.dart';
import 'vcs_member.dart';

/// Handles Gerrit-related operations for Git projects
///
/// This class provides methods to interact with Gerrit code review system,
/// including retrieving change information, conflicts data, and URLs.
///
/// Example usage:
/// ```dart
/// final project = Project.fromPath('/path/to/git/repo');
/// final gerritHandler = GerritHandler.to(project);
///
/// if (gerritHandler != null) {
///   // Get conflicts info for a specific change and revision
///   final conflicts = await gerritHandler.getConflictsInfo(
///     changeId: '12345',
///     revisionId: 'current',
///   );
///
///   if (conflicts != null && conflicts.containsConflicts) {
///     print('This revision has merge conflicts!');
///     print('Base: ${conflicts.base}');
///     print('Ours: ${conflicts.ours}');
///     print('Theirs: ${conflicts.theirs}');
///   }
///
///   // Or use with a branch object
///   final branch = project.vcs.branches.first;
///   final branchConflicts = await gerritHandler.getConflictsInfoForBranch(branch);
/// }
/// ```
class GerritHandler {
  static GerritHandler? to(Project project) {
    try {
      return GerritHandler._(project);
    } on GerritHandlerException catch (_) {
      return null;
    }
  }

  GerritHandler._(this._project) {
    final vcs = _project.vcs;
    if (vcs is! Git) {
      throw GerritHandlerException('Project is not using Git');
    }
    _git = vcs;
  }

  final Project _project;
  late final Git _git;

  /// Gets the ConflictsInfo for a specific revision patchset using a Branch
  /// object.
  ///
  /// This is a convenience method that extracts the change ID from the branch's
  /// Gerrit configuration and gets conflicts info for the current revision.
  ///
  /// Parameters:
  /// - [branch]: The branch object containing Gerrit configuration
  /// - [revisionId]: The revision identifier (defaults to 'current')
  ///
  /// Returns:
  /// - [GerritConflictsInfo] if the revision has conflicts information available
  /// - [null] if no Gerrit issue is configured for the branch or no conflicts
  /// information is available
  ///
  /// Throws:
  /// - [GerritHandlerException] if there's an error making the API request
  Future<GerritConflictsInfo?> getConflictsInfoForBranch(
    Branch branch, {
    String revisionId = 'current',
  }) async {
    final changeId = await getGerritUrl(branch);
    if (changeId == null) {
      return null;
    }

    return getConflictsInfo(changeUrl: changeId, revisionId: revisionId);
  }

  /// Gets the ConflictsInfo for a specific revision patchset
  ///
  /// This method retrieves conflict information for a revision by calling the
  /// Gerrit REST API.
  /// The conflicts info contains information about merge conflicts, base
  /// commits, and merge strategies.
  ///
  /// Parameters:
  /// - [changeUrl]: The change identifier (can be change number, Change-Id, or
  /// project~branch~Change-Id format)
  /// - [revisionId]: The revision identifier (can be 'current', patch set
  /// number, or commit SHA)
  /// - [serverUrl]: The Gerrit server base URL (optional, will try to get from
  /// git config if not provided)
  ///
  /// Returns:
  /// - [GerritConflictsInfo] if the revision has conflicts information available
  /// - `null` if no conflicts information is available or if the request fails
  ///
  /// Throws:
  /// - [GerritHandlerException] if there's an error making the API request
  Future<GerritConflictsInfo?> getConflictsInfo({
    required String changeUrl,
    required String revisionId,
    String? serverUrl,
  }) async {
    try {
      // Construct the API endpoint URL
      // GET /changes/{change-id}/revisions/{revision-id}
      final apiUrl = '$changeUrl/revisions/$revisionId';

      // Make the HTTP request
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        // Return null for common error cases (not found, no permission, etc.)
        return null;
      }

      // Parse the response (Gerrit prepends ")]}'" to JSON responses for
      // security)
      var responseBody = response.body;
      if (responseBody.startsWith(")]}'\n")) {
        responseBody = responseBody.substring(5);
      }

      final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;

      // Check if conflicts information is available
      final conflictsData = jsonData['conflicts'] as Map<String, dynamic>?;
      if (conflictsData == null) {
        return null;
      }

      return GerritConflictsInfo.fromJson(conflictsData);
    } catch (e) {
      throw GerritHandlerException(
        'Failed to get conflicts info for change "$changeUrl", revision '
        '"$revisionId": $e',
      );
    }
  }

  Future<String?> getGerritInfo(Branch branch) async {
    try {
      final gerritIssue = await getGerritIssue(branch);
      if (gerritIssue == null) {
        return null;
      }

      final status = await getChangeStatus(branch);
      if (status == null) {
        return null;
      }

      final buffer = StringBuffer();
      buffer.write(gerritIssue);

      // Optionally add conflicts info for NEW changes
      if (status == ChangeStatus.NEW) {
        final conflicts = await getConflictsInfoForBranch(branch);
        if (conflicts != null && conflicts.containsConflicts) {
          buffer.write(' - MERGE CONFLICTS');
        }
      } else {
        buffer.write(' - ${status.name}');
      }

      return buffer.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getGerritIssue(Branch branch) async {
    try {
      // Run git config to get the gerritissue for the specific branch
      final result = await Process.run('git', [
        'config',
        '--get',
        'branch.${branch.name}.gerritissue',
      ], workingDirectory: _git.project.path);

      if (result.exitCode != 0) {
        // Branch doesn't have a Gerrit issue configured
        return null;
      }

      final gerritIssue = (result.stdout as String).trim();
      if (gerritIssue.isEmpty) {
        return null;
      }
      return gerritIssue;
    } catch (e) {
      throw GerritHandlerException(
        'Failed to get Gerrit issue for branch "${branch.name}": $e',
      );
    }
  }

  Future<String?> getGerritUrl(Branch branch) async {
    try {
      // Get the Gerrit issue number
      final issueNumber = await getGerritIssue(branch);
      if (issueNumber == null) {
        return null;
      }

      // Get the Gerrit server URL
      final serverResult = await Process.run('git', [
        'config',
        '--get',
        'branch.${branch.name}.gerritserver',
      ], workingDirectory: _git.project.path);

      if (serverResult.exitCode != 0) {
        return null;
      }

      final serverUrl = (serverResult.stdout as String).trim();
      if (serverUrl.isEmpty) {
        return null;
      }

      // Build the Gerrit URL: {server}/c/{project}/+/{issue}
      return '$serverUrl/c/sdk/+/$issueNumber';
    } catch (_) {
      return null;
    }
  }

  /// Gets the change status from Gerrit for a specific branch
  ///
  /// This method retrieves the change status (NEW, MERGED, ABANDONED) from Gerrit
  /// by calling the GET /changes/{change-id} REST API endpoint.
  ///
  /// Parameters:
  /// - [branch]: The branch object containing Gerrit configuration
  ///
  /// Returns:
  /// - [ChangeStatus] if all works well
  /// - [null] if no Gerrit issue is configured for the branch or if the request fails
  ///
  /// Throws:
  /// - [GerritHandlerException] if there's an error making the API request
  Future<ChangeStatus?> getChangeStatus(Branch branch) async {
    try {
      final changeUrl = await getGerritUrl(branch);
      if (changeUrl == null) {
        return null;
      }

      // Make the HTTP request to get change info
      final response = await http.get(
        Uri.parse(changeUrl),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        // Return null for common error cases (not found, no permission, etc.)
        return null;
      }

      // Parse the response (Gerrit prepends ")]}'" to JSON responses for
      // security)
      var responseBody = response.body;
      if (responseBody.startsWith(")]}'\n")) {
        responseBody = responseBody.substring(5);
      }

      final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;

      // Extract the status field
      final status = jsonData['status'] as String?;

      if (status == null) {
        return null;
      }

      return ChangeStatus.values.byName(status);
    } catch (e) {
      throw GerritHandlerException(
        'Failed to get change status for branch "${branch.name}": $e',
      );
    }
  }

  getInfo(Commit lastCommit) {}
}

class GerritHandlerException implements Exception {
  GerritHandlerException(this.message);

  final String message;

  @override
  String toString() {
    return 'GerritHandlerException: $message';
  }
}

/// Represents the conflicts information for a revision patchset
class GerritConflictsInfo {
  const GerritConflictsInfo({
    this.base,
    this.ours,
    this.theirs,
    this.mergeStrategy,
    this.noBaseReason,
    required this.containsConflicts,
  });

  /// The SHA1 of the commit that was used as the base commit for the Git merge
  final String? base;

  /// The SHA1 of the commit that was used as "ours" for the Git merge
  final String? ours;

  /// The SHA1 of the commit that was used as "theirs" for the Git merge
  final String? theirs;

  /// The merge strategy used for the Git merge (resolve, recursive,
  /// simple-two-way-in-core, ours, theirs)
  final String? mergeStrategy;

  /// Reason why base is not set (NO_COMMON_ANCESTOR, COMPUTED_BASE,
  /// ONE_SIDED_MERGE_STRATEGY, NO_MERGE_PERFORMED, HISTORIC_DATA_WITHOUT_BASE)
  final String? noBaseReason;

  /// Whether any of the files in the revision has a conflict due to merging
  /// "ours" and "theirs"
  final bool containsConflicts;

  factory GerritConflictsInfo.fromJson(Map<String, dynamic> json) {
    return GerritConflictsInfo(
      base: json['base'] as String?,
      ours: json['ours'] as String?,
      theirs: json['theirs'] as String?,
      mergeStrategy: json['merge_strategy'] as String?,
      noBaseReason: json['no_base_reason'] as String?,
      containsConflicts: json['contains_conflicts'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (base != null) 'base': base,
      if (ours != null) 'ours': ours,
      if (theirs != null) 'theirs': theirs,
      if (mergeStrategy != null) 'merge_strategy': mergeStrategy,
      if (noBaseReason != null) 'no_base_reason': noBaseReason,
      'contains_conflicts': containsConflicts,
    };
  }

  @override
  String toString() {
    return 'ConflictsInfo('
        'base: $base, '
        'ours: $ours, '
        'theirs: $theirs, '
        'mergeStrategy: $mergeStrategy, '
        'noBaseReason: $noBaseReason, '
        'containsConflicts: $containsConflicts'
        ')';
  }
}

enum ChangeStatus { NEW, MERGED, ABANDONED }
