import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../../cli_name.dart';
import '../../errors.dart';
import '../../sdk/sdk_cache.dart';
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
      '(project version, falling back to the global version).\n'
      'Installs that version first if it is not installed yet.';

  @override
  String get invocation => '$cliName $name [arguments]';

  /// The configured SDK, installed first if it is missing or incomplete.
  Future<InstalledSdk> _selectedSdk() async {
    final cwd = context.workingDirectory;
    final configured = context.resolver.requireConfigured(cwd);
    if (context.cache.isInstalled(configured.version)) {
      return context.cache.find(configured.version)!;
    }

    final where = configured.isGlobal
        ? 'as the global version'
        : 'in ${p.relative(configured.source, from: cwd)}';
    logger.infoToStderr = true;
    try {
      logger.info('Flutter ${configured.version} is set $where but is not '
          'installed yet. Installing it now...');
      final result =
          await context.provisioner.ensureInstalled(configured.version);
      logger.info('Flutter ${result.name} installed successfully.');
      logger.info('');
      return context.cache.find(result.name)!;
    } finally {
      logger.infoToStderr = false;
    }
  }

  @override
  Future<int> run() async {
    final sdk = await _selectedSdk();
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
