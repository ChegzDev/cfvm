import '../../config/project_config.dart';
import 'cfvm_command.dart';
import '../../cli_name.dart';

class ListCommand extends CfvmCommand {
  ListCommand(super.context);

  @override
  String get name => 'list';

  @override
  String get description => 'List locally installed Flutter SDK versions.';

  @override
  String get invocation => '$cliName list';

  @override
  Future<int> run() async {
    optionalArgument(); // Rejects stray arguments.
    final sdks = context.cache.list();
    final global = context.loadGlobalConfig().globalVersion;
    final project = ProjectConfig.find(context.workingDirectory);

    if (sdks.isEmpty) {
      logger.info('No Flutter SDKs installed.');
      logger.info('Install one with: $cliName install stable');
    } else {
      logger.info('Installed Flutter SDKs (${context.home.versionsDir}):');
      final width =
          sdks.map((s) => s.name.length).reduce((a, b) => a > b ? a : b);
      for (final sdk in sdks) {
        final tags = [
          if (sdk.name == project?.flutterVersion) 'project',
          if (sdk.name == global) 'global',
          if (!sdk.isComplete) 'incomplete',
        ];
        final suffix = tags.isEmpty ? '' : '  (${tags.join(', ')})';
        logger.info('  ${sdk.name.padRight(width)}$suffix'.trimRight());
      }
    }

    logger.info('');
    if (project != null) {
      final missing = context.cache.isInstalled(project.flutterVersion)
          ? ''
          : '  [not installed]';
      logger.info('Project version: ${project.flutterVersion}'
          ' (${project.filePath})$missing');
    }
    if (global == null) {
      logger.info('Global version:  not set');
    } else {
      final missing =
          context.cache.isInstalled(global) ? '' : '  [not installed]';
      logger.info('Global version:  $global$missing');
    }
    return 0;
  }
}
