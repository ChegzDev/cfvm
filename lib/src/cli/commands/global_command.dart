import 'cfvm_command.dart';
import '../../cli_name.dart';

class GlobalCommand extends CfvmCommand {
  GlobalCommand(super.context);

  @override
  String get name => 'global';

  @override
  String get description =>
      'Set the default Flutter SDK version, used outside projects that have '
      'their own version.\nInstalls the version first if it is not installed '
      'yet. Without a version, shows the current global version.';

  @override
  String get invocation => '$cliName global [version]';

  @override
  Future<int> run() async {
    final request = optionalArgument();
    final config = context.loadGlobalConfig();

    if (request == null) {
      final current = config.globalVersion;
      logger.info(current == null
          ? 'No global Flutter version set. Set one with: $cliName global <version>'
          : 'Global Flutter version: $current');
      return 0;
    }

    final version = await installIfMissing(request);
    config.globalVersion = version;
    context.saveGlobalConfig(config);
    logger.info('Global Flutter version set to $version.');
    logger.info('(Your system PATH is not changed. '
        'Run Flutter with: $cliName flutter <command>)');
    return 0;
  }
}
