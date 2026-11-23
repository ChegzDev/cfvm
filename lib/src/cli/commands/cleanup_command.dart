import 'dart:io';

import '../../config/project_config.dart';
import '../../errors.dart';
import '../../sdk/sdk_cache.dart';
import 'cfvm_command.dart';
import '../../cli_name.dart';

class CleanupCommand extends CfvmCommand {
  CleanupCommand(super.context) {
    argParser.addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Remove all unused versions without prompting.',
    );
  }

  @override
  String get name => 'cleanup';

  @override
  String get description =>
      'Find installed SDK versions that are not used globally or by any '
      'known project, and optionally remove them.';

  @override
  String get invocation => '$cliName cleanup [--yes]';

  @override
  Future<int> run() async {
    optionalArgument(); // Rejects stray arguments.
    _removeInterruptedInstallLeftovers();

    final sdks = context.cache.list();
    if (sdks.isEmpty) {
      logger.info('No Flutter SDKs installed. Nothing to clean up.');
      return 0;
    }

    final usage = _collectUsage();
    final unused = [
      for (final s in sdks)
        if (!usage.containsKey(s.name)) s
    ];

    final inUse = [
      for (final s in sdks)
        if (usage.containsKey(s.name)) s
    ];
    if (inUse.isNotEmpty) {
      logger.info('In use:');
      for (final sdk in inUse) {
        logger.info('  ${sdk.name}  <- ${usage[sdk.name]!.join(', ')}');
      }
    }
    if (unused.isEmpty) {
      logger.info('All installed versions are in use. Nothing to clean up.');
      return 0;
    }

    logger.info('Unused:');
    final sizes = {for (final s in unused) s.name: _sizeOf(s.path)};
    for (final sdk in unused) {
      final note = sdk.isComplete ? '' : ', incomplete';
      logger.info('  ${sdk.name}  (${_mb(sizes[sdk.name]!)} MB$note)');
    }
    logger.info('');

    final List<InstalledSdk> toRemove;
    if (argResults!['yes'] as bool) {
      toRemove = unused;
    } else if (!context.prompter.isInteractive) {
      logger.info('Run "$cliName cleanup --yes" to remove them.');
      return 0;
    } else {
      toRemove = _choose(unused);
    }

    if (toRemove.isEmpty) {
      logger.info('Nothing removed.');
      return 0;
    }
    var freed = 0;
    for (final sdk in toRemove) {
      logger.info('Removing Flutter ${sdk.name}...');
      await context.cache.remove(sdk);
      freed += sizes[sdk.name]!;
    }
    logger.info('Removed ${toRemove.length} version(s), '
        'freed ${_mb(freed)} MB.');
    return 0;
  }

  List<InstalledSdk> _choose(List<InstalledSdk> unused) {
    final answer = context.prompter
        .ask('Remove unused versions? [a]ll / [s]elect individually / '
            '[N]one: ')
        ?.trim()
        .toLowerCase();
    switch (answer) {
      case 'a':
      case 'all':
        return unused;
      case 's':
      case 'select':
        return [
          for (final sdk in unused)
            if (context.prompter.confirm('Remove Flutter ${sdk.name}?')) sdk,
        ];
      default:
        return const [];
    }
  }

  /// Maps each used version to the reasons it is used. Forgets tracked
  /// projects that no longer exist or no longer have a CFVM config.
  Map<String, List<String>> _collectUsage() {
    final usage = <String, List<String>>{};
    void use(String version, String reason) =>
        (usage[version] ??= []).add(reason);

    final config = context.loadGlobalConfig();
    final global = config.globalVersion;
    if (global != null) use(global, 'global');

    final stale = <String>[];
    for (final dir in config.projects) {
      try {
        final project = ProjectConfig.load(dir);
        if (project == null) {
          stale.add(dir);
        } else {
          use(project.flutterVersion, dir);
        }
      } on CfvmException catch (e) {
        // Keep the entry; the user may fix the file.
        logger.warn(e.message);
      }
    }
    if (stale.isNotEmpty) {
      config.projects.removeWhere(stale.contains);
      context.saveGlobalConfig(config);
    }

    // The current project counts even if `cfvm use` never ran here.
    final current = ProjectConfig.find(context.workingDirectory);
    if (current != null &&
        !(usage[current.flutterVersion]?.contains(current.directory) ??
            false)) {
      use(current.flutterVersion, current.directory);
    }
    return usage;
  }

  /// Interrupted downloads and extractions are CFVM's own temporary files,
  /// never a usable SDK, so they are removed without prompting.
  void _removeInterruptedInstallLeftovers() {
    final temp = Directory(context.home.tempDir);
    if (!temp.existsSync()) return;
    final hadFiles = temp.listSync().isNotEmpty;
    final size = _sizeOf(temp.path);
    temp.deleteSync(recursive: true);
    if (!hadFiles) return;
    logger.info('Removed leftover files from interrupted installs '
        '(${_mb(size)} MB).');
  }

  static int _sizeOf(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
