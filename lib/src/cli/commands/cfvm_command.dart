import 'package:args/command_runner.dart';

import '../../context.dart';
import '../../io/logger.dart';

/// Base class for CFVM commands.
abstract class CfvmCommand extends Command<int> {
  CfvmCommand(this.context);

  final CfvmContext context;

  Logger get logger => context.logger;

  /// The single positional argument, or null if none was given.
  String? optionalArgument() {
    final rest = argResults!.rest;
    if (rest.length > 1) usageException('Too many arguments.');
    return rest.isEmpty ? null : rest.single;
  }

  /// Installs [request] if it is not installed yet (like `install` would)
  /// and returns the installed SDK name.
  Future<String> installIfMissing(String request) async {
    final result = await context.provisioner.ensureInstalled(request);
    if (result.newlyInstalled) {
      logger.info('Flutter ${result.name} installed successfully.');
      logger.info('');
    }
    return result.name;
  }

  /// The single positional argument, which is required.
  String requiredArgument(String name) =>
      optionalArgument() ?? usageException('Missing <$name> argument.');
}
