import 'dart:async';
import 'dart:io';

/// Runs external processes. Abstracted so commands can be tested without
/// spawning real processes.
abstract class ProcessRunner {
  /// Runs [executable] attached to this terminal (stdin/stdout/stderr are
  /// inherited) and returns its exit code.
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  });

  /// Runs [executable] and captures its output.
  Future<ProcessResult> runCaptured(String executable, List<String> arguments);
}

class IoProcessRunner implements ProcessRunner {
  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      environment: environment,
      mode: ProcessStartMode.inheritStdio,
      // Windows needs cmd.exe to run .bat files such as flutter.bat.
      runInShell:
          Platform.isWindows && executable.toLowerCase().endsWith('.bat'),
    );
    // Ctrl+C reaches the child directly (same terminal). Ignore it here so
    // CFVM waits for the child to shut down cleanly instead of exiting first.
    final sigint = ProcessSignal.sigint.watch().listen((_) {});
    try {
      return await process.exitCode;
    } finally {
      await sigint.cancel();
    }
  }

  @override
  Future<ProcessResult> runCaptured(
          String executable, List<String> arguments) =>
      Process.run(executable, arguments);
}
