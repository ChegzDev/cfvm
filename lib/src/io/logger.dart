import 'dart:io';

/// Minimal terminal output. Normal output goes to stdout; warnings, errors
/// and verbose details go to stderr so they never pollute the output of
/// proxied `flutter`/`dart` commands.
class Logger {
  Logger({StringSink? out, StringSink? err, bool? showProgress})
      : _out = out ?? stdout,
        _err = err ?? stderr,
        _showProgress = showProgress ?? (out == null && stdout.hasTerminal);

  final StringSink _out;
  final StringSink _err;
  final bool _showProgress;

  /// Enables [detail] output. Set from the global `--verbose` flag.
  bool verbose = false;

  /// Sends [info] and progress output to stderr, so it does not mix with
  /// the stdout of a proxied `flutter`/`dart` command.
  bool infoToStderr = false;

  StringSink get _info => infoToStderr ? _err : _out;

  void info(String message) => _info.writeln(message);

  void warn(String message) => _err.writeln('Warning: $message');

  void error(String message) => _err.writeln('Error: $message');

  void detail(String message) {
    if (verbose) _err.writeln(message);
  }

  /// Rewrites the current terminal line (no-op when not on a terminal).
  void progress(String message) {
    if (_showProgress) _info.write('\r$message');
  }

  /// Ends a sequence of [progress] updates.
  void progressDone() {
    if (_showProgress) _info.writeln();
  }
}
