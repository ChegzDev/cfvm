import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../context.dart';
import '../errors.dart';
import 'commands/cleanup_command.dart';
import 'commands/global_command.dart';
import 'commands/install_command.dart';
import 'commands/list_command.dart';
import 'commands/sdk_proxy_command.dart';
import 'commands/use_command.dart';
import '../cli_name.dart';

class CfvmCommandRunner extends CommandRunner<int> {
  CfvmCommandRunner(this.context)
      : super(
            cliName,
            'CFVM (Chegz Flutter Version Management)\n'
            'Install multiple Flutter SDKs and switch between them per '
            'project.') {
    argParser.addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Print extra diagnostic output.');
    addCommand(UseCommand(context));
    addCommand(InstallCommand(context));
    addCommand(ListCommand(context));
    addCommand(CleanupCommand(context));
    addCommand(GlobalCommand(context));
    addCommand(SdkProxyCommand.flutter(context));
    addCommand(SdkProxyCommand.dart(context));
  }

  final CfvmContext context;

  /// Runs the CLI and returns the process exit code. Never throws for
  /// expected failures.
  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await super.run(args) ?? 0;
    } on UsageException catch (e) {
      context.logger.error(e.message);
      context.logger.info('');
      context.logger.info(e.usage);
      return 64; // EX_USAGE
    } on CfvmException catch (e) {
      context.logger.error(e.message);
      if (e.hint != null) context.logger.info(e.hint!);
      return 1;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) {
    context.logger.verbose = topLevelResults['verbose'] as bool;
    return super.runCommand(topLevelResults);
  }
}
