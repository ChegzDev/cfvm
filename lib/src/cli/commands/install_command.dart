import '../../version.dart';
import 'cfvm_command.dart';
import '../../cli_name.dart';

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
    final name = canonicalVersion(request);
    validateVersionName(name);

    if (gitChannels.contains(name)) {
      if (context.cache.isInstalled(name)) {
        logger.info('Flutter $name is already installed. '
            'To update it, run: $cliName flutter upgrade (with $name selected)');
        return 0;
      }
      if (!await _confirmInstallable(name)) return 1;
      await context.installer.installFromGit(name);
      _printDone(name);
      return 0;
    }

    // Concrete versions that are already installed need no network access.
    if (!archiveChannels.contains(name) && context.cache.isInstalled(name)) {
      logger.info('Flutter $name is already installed.');
      return 0;
    }

    final index = await context.releases.fetch();
    final release = index.resolve(name, context.host);
    final label = archiveChannels.contains(name)
        ? '${release.name} (current $name)'
        : release.name;
    if (context.cache.isInstalled(release.name)) {
      logger.info('Flutter $label is already installed.');
      return 0;
    }
    if (!await _confirmInstallable(release.name)) return 1;

    if (release.effectiveArch != context.host.arch) {
      logger.warn('No ${context.host.arch} build of Flutter ${release.name} '
          'exists; installing the ${release.effectiveArch} build '
          '(runs under emulation).');
    }
    logger.info('Installing Flutter $label '
        '[${release.channel}, ${context.host.os}-${release.effectiveArch}]');
    await context.installer.installRelease(release, baseUrl: index.baseUrl);
    _printDone(release.name);
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

  /// Handles a leftover directory that is not a complete SDK. Never deletes
  /// it without explicit confirmation.
  Future<bool> _confirmInstallable(String name) async {
    final existing = context.cache.find(name);
    if (existing == null) return true;
    logger.warn('${existing.path} exists but is not a complete Flutter SDK.');
    if (!context.prompter.confirm('Delete it and reinstall Flutter $name?')) {
      logger.info('Installation cancelled. Nothing was changed.');
      return false;
    }
    await context.cache.remove(existing);
    return true;
  }

  void _printDone(String name) {
    logger.info('');
    logger.info('Flutter $name installed successfully.');
    logger.info('Use it in a project:  $cliName use $name');
    logger.info('Or set as default:    $cliName global $name');
  }
}
