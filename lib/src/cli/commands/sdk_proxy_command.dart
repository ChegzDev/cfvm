import 'dart:io';

import 'package:args/args.dart';

import '../../errors.dart';
import 'cfvm_command.dart';

/// Runs `flutter` or `dart` from the SDK selected for the current directory,
/// passing all arguments through untouched.
class SdkProxyCommand extends CfvmCommand {
  SdkProxyCommand.flutter(super.context) : name = 'flutter';
  SdkProxyCommand.dart(super.context) : name = 'dart';

  @override
  final String name;

  @override
  final ArgParser argParser = ArgParser.allowAnything();

  @override
  String get description => 'Run a $name command with the selected Flutter SDK '
      '(project version, falling back to the global version).';

  @override
  String get invocation => 'cfvm $name [arguments]';

  @override
  Future<int> run() async {
    final sdk = context.resolver.resolveActive(context.workingDirectory);
    final executable =
        name == 'flutter' ? sdk.flutterExecutable : sdk.dartExecutable;
    logger.detail('Using Flutter ${sdk.name} at ${sdk.path}');

    // Put the selected SDK first on PATH for the child process only, so
    // tools it launches also use this SDK. The user's PATH is not modified.
    final environment = Map<String, String>.of(context.environment);
    final pathKey = environment.keys.firstWhere(
      (k) => k.toUpperCase() == 'PATH',
      orElse: () => 'PATH',
    );
    final separator = context.host.isWindows ? ';' : ':';
    final current = environment[pathKey];
    environment[pathKey] = current == null || current.isEmpty
        ? sdk.binDir
        : '${sdk.binDir}$separator$current';

    try {
      return await context.processRunner.runInteractive(
        executable,
        argResults!.rest,
        environment: environment,
      );
    } on ProcessException catch (e) {
      throw CfvmException('Failed to run $executable: ${e.message}');
    }
  }
}
