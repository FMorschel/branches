import 'package:equatable/equatable.dart';
import 'vcs_member_visitor.dart';

sealed class VcsMember {
  T? accept<T>(VcsMemberVisitor<T> visitor);
}

class Branch extends Equatable implements VcsMember {
  Branch({required this.name, required this.lastCommit});

  final Commit lastCommit;
  final String name;

  @override
  T? accept<T>(VcsMemberVisitor<T> visitor) => visitor.visitBranch(this);

  @override
  List<Object?> get props => [name, lastCommit];
}

class Commit extends Equatable implements VcsMember {
  Commit({
    required this.id,
    required this.message,
    required this.date,
    required this.author,
  });

  String shortId({int length = 7}) {
    return id.length <= length ? id : id.substring(0, length);
  }

  @override
  T? accept<T>(VcsMemberVisitor<T> visitor) => visitor.visitCommit(this);

  final String id;
  final String message;
  final DateTime date;
  final Author author;

  @override
  List<Object?> get props => [id, message, date, author];
}

class Author extends Equatable implements VcsMember {
  Author({required this.name, required this.email});

  final String name;
  final String email;

  @override
  T? accept<T>(VcsMemberVisitor<T> visitor) => visitor.visitAuthor(this);

  @override
  List<Object?> get props => [name, email];
}
