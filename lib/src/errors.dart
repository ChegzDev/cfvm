/// An expected, user-facing failure. The CLI prints [message] (and [hint],
/// if present) without a stack trace and exits with a non-zero code.
class CfvmException implements Exception {
  const CfvmException(this.message, {this.hint});

  final String message;

  /// Optional suggestion telling the user how to fix the problem.
  final String? hint;

  @override
  String toString() => hint == null ? message : '$message\n$hint';
}
