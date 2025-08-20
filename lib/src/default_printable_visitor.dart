import 'vcs_member.dart';
import 'vcs_member_visitor.dart';

class DefaultPrintableVisitor extends VcsMemberVisitor<String> {
  @override
  String visitBranch(Branch branch) {
    return 'Branch: ${branch.name}\n'
        'Last Commit: ${branch.lastCommit.shortId()}';
  }

  @override
  String visitCommit(Commit commit) {
    return 'Commit: ${commit.shortId()}\nMessage: ${commit.message}\n'
        'Date: ${commit.date}\n'
        '${commit.author.accept(this)}';
  }

  @override
  String visitAuthor(Author author) {
    return 'Author: ${author.name} <${author.email}>';
  }
}
