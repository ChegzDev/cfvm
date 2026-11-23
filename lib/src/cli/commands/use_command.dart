import 'package:path/path.dart' as p;
import '../../config/project_config.dart';
import 'cfvm_command.dart';
import '../../cli_name.dart';

class UseCommand extends CfvmCommand {
  UseCommand(super.context);

  @override
  String get name => 'use';

  @override
  String get description =>
      'Set the Flutter SDK version for the current project '
      '(writes ${ProjectConfig.fileName}).\n'
      'Installs the version first if it is not installed yet.';

  @override
  String get invocation => '$cliName use <version>';

  @override
  Future<int> run() async {
    final request = requiredArgument('version');
    final version = await installIfMissing(request);

    var root = ProjectConfig.findProjectRoot(context.workingDirectory);
    if (root == null) {
      root = p.normalize(p.absolute(context.workingDirectory));
      logger.warn('No pubspec.yaml found; '
          'writing ${ProjectConfig.fileName} to the current directory.');
    }
    final config = ProjectConfig.save(root, version);

    // Remember the project so `cleanup` knows this version is in use.
    final global = context.loadGlobalConfig()..addProject(root);
    context.saveGlobalConfig(global);

    logger.info('Project now uses Flutter $version (${config.filePath}).');
    logger.info('Run Flutter with: $cliName flutter <command>');
    return 0;
  }
}
