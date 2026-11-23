import 'package:path/path.dart' as p;

import '../config/global_config.dart';
import '../config/project_config.dart';
import '../errors.dart';
import 'cfvm_home.dart';
import 'sdk_cache.dart';
import '../cli_name.dart';

/// A version selected by configuration, and where it came from.
class ConfiguredVersion {
  const ConfiguredVersion(this.version, this.source);

  final String version;

  /// Human-readable origin, e.g. `/app/.cfvm.json` or `global`.
  final String source;

  bool get isGlobal => source == 'global';
}

/// Decides which Flutter SDK to use.
class VersionResolver {
  VersionResolver({required this.home, required this.cache});

  final CfvmHome home;
  final SdkCache cache;

  /// The project version for [directory] (searching parent directories),
  /// falling back to the global version. Null if neither is set.
  ConfiguredVersion? configuredVersion(String directory) {
    final project = ProjectConfig.find(directory);
    if (project != null) {
      return ConfiguredVersion(project.flutterVersion, project.filePath);
    }
    final global = GlobalConfig.load(home.configPath).globalVersion;
    if (global != null) return ConfiguredVersion(global, 'global');
    return null;
  }

  /// The installed SDK to run `flutter`/`dart` with in [directory].
  InstalledSdk resolveActive(String directory) {
    final configured = configuredVersion(directory);
    if (configured == null) {
      throw const CfvmException(
        'No Flutter version configured.',
        hint: 'Run "$cliName use <version>" in your project, '
            'or "$cliName global <version>" to set a default.',
      );
    }
    final where = configured.isGlobal
        ? 'as the global version'
        : 'in ${p.relative(configured.source, from: directory)}';
    final sdk = cache.find(configured.version);
    if (sdk == null) {
      throw CfvmException(
        'Flutter ${configured.version} is configured $where '
        'but is not installed.',
        hint: 'Install it with: $cliName install ${configured.version}',
      );
    }
    if (!sdk.isComplete) {
      throw CfvmException(
        'Flutter ${configured.version} is configured $where but its '
        'installation at ${sdk.path} is incomplete.',
        hint: 'Reinstall it with: $cliName install ${configured.version}',
      );
    }
    return sdk;
  }
}
