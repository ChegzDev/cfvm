import '../errors.dart';
import '../io/logger.dart';
import '../io/prompter.dart';
import '../platform.dart';
import '../releases/flutter_releases.dart';
import '../version.dart';
import 'sdk_cache.dart';
import 'sdk_installer.dart';

/// Outcome of [SdkProvisioner.ensureInstalled].
class ProvisionResult {
  const ProvisionResult(this.name,
      {required this.newlyInstalled, this.channel});

  /// Name of the installed SDK (its directory under `versions/`).
  final String name;

  /// False if the SDK was already installed.
  final bool newlyInstalled;

  /// The channel the request named (`stable`/`beta`), if any.
  final String? channel;

  /// e.g. `3.22.1 (current stable)` or `3.19.0`.
  String get label => channel == null ? name : '$name (current $channel)';
}

/// Turns a version or channel request into an installed SDK, installing it
/// when missing. Shared by `install`, `use` and `global`.
class SdkProvisioner {
  SdkProvisioner({
    required this.cache,
    required this.releases,
    required this.installer,
    required this.host,
    required this.logger,
    required this.prompter,
  });

  final SdkCache cache;
  final ReleaseRepository releases;
  final SdkInstaller installer;
  final HostPlatform host;
  final Logger logger;
  final Prompter prompter;

  /// Ensures the SDK for [request] (a version such as `3.19.0`, or a channel:
  /// `stable`, `beta`, `master`) is installed and returns its name.
  ///
  /// Channels `stable`/`beta` resolve to their current release. Versions
  /// that are already installed are returned without network access.
  Future<ProvisionResult> ensureInstalled(String request) async {
    final name = canonicalVersion(request);
    validateVersionName(name);

    if (gitChannels.contains(name)) {
      if (cache.isInstalled(name)) {
        return ProvisionResult(name, newlyInstalled: false);
      }
      await _clearIncomplete(name);
      logger.info('Installing Flutter $name from git...');
      await installer.installFromGit(name);
      return ProvisionResult(name, newlyInstalled: true);
    }

    final channel = archiveChannels.contains(name) ? name : null;
    if (channel == null && cache.isInstalled(name)) {
      return ProvisionResult(name, newlyInstalled: false);
    }

    final index = await releases.fetch();
    final release = index.resolve(name, host);
    if (cache.isInstalled(release.name)) {
      return ProvisionResult(release.name,
          newlyInstalled: false, channel: channel);
    }
    await _clearIncomplete(release.name);

    final result =
        ProvisionResult(release.name, newlyInstalled: true, channel: channel);
    if (release.effectiveArch != host.arch) {
      logger.warn('No ${host.arch} build of Flutter ${release.name} '
          'exists; installing the ${release.effectiveArch} build '
          '(runs under emulation).');
    }
    logger.info('Installing Flutter ${result.label} '
        '[${release.channel}, ${host.os}-${release.effectiveArch}]');
    await installer.installRelease(release, baseUrl: index.baseUrl);
    return result;
  }

  /// Handles a leftover directory that is not a complete SDK. Never deletes
  /// it without explicit confirmation.
  Future<void> _clearIncomplete(String name) async {
    final existing = cache.find(name);
    if (existing == null) return;
    logger.warn('${existing.path} exists but is not a complete Flutter SDK.');
    if (!prompter.confirm('Delete it and reinstall Flutter $name?')) {
      throw CfvmException(
        'Installation of Flutter $name cancelled. Nothing was changed.',
        hint: 'Run the command in a terminal to confirm the reinstall, or '
            'delete ${existing.path} yourself.',
      );
    }
    await cache.remove(existing);
  }
}
