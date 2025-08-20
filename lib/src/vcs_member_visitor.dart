import 'vcs_member.dart';

abstract class VcsMemberVisitor<T> {
  T? visitBranch(Branch branch);
  T? visitCommit(Commit commit);
  T? visitAuthor(Author author);
}
