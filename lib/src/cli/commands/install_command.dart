import '../../cli_name.dart';
import '../../version.dart';
import 'cfvm_command.dart';

class InstallCommand extends CfvmCommand {
  InstallCommand(super.context);

  @override
  String get name => 'install';

  @override
  String get description =>
      'Download and install a Flutter SDK version or channel '
      '(e.g. 3.19.0, stable, beta, master).\n'
      'Without a version, installs the version configured for the current '
      'project (or the global version).';

  @override
  String get invocation => '$cliName install [version]';

  @override
  Future<int> run() async {
    final request = optionalArgument() ?? _configuredVersion();
    final result = await context.provisioner.ensureInstalled(request);

    if (!result.newlyInstalled) {
      logger.info('Flutter ${result.label} is already installed.');
      if (gitChannels.contains(result.name)) {
        logger.info('To update it, run: $cliName flutter upgrade '
            '(with ${result.name} selected)');
      }
      return 0;
    }
    logger.info('');
    logger.info('Flutter ${result.name} installed successfully.');
    logger.info('Use it in a project:  $cliName use ${result.name}');
    logger.info('Or set as default:    $cliName global ${result.name}');
    return 0;
  }

  String _configuredVersion() {
    final configured =
        context.resolver.configuredVersion(context.workingDirectory);
    if (configured == null) {
      usageException('No version given and none is configured '
          'for this project or globally.');
    }
    logger.info('Using configured version ${configured.version} '
        '(from ${configured.source}).');
    return configured.version;
  }
}
