import 'dart:io';

/// Asks the user questions on the terminal.
abstract class Prompter {
  /// Whether a human can answer prompts (stdin is a terminal).
  bool get isInteractive;

  /// Prints [question] and returns the entered line, or null on EOF.
  String? ask(String question);

  /// Asks a yes/no question that defaults to "no". Always returns false
  /// when not interactive, so nothing destructive happens unattended.
  bool confirm(String question) {
    if (!isInteractive) return false;
    final answer = ask('$question [y/N] ')?.trim().toLowerCase();
    return answer == 'y' || answer == 'yes';
  }
}

class StdioPrompter extends Prompter {
  @override
  bool get isInteractive => stdin.hasTerminal;

  @override
  String? ask(String question) {
    stdout.write(question);
    return stdin.readLineSync();
  }
}
