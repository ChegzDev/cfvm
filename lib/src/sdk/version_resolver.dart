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

  /// Like [configuredVersion], but fails with a helpful message when no
  /// version is configured.
  ConfiguredVersion requireConfigured(String directory) {
    final configured = configuredVersion(directory);
    if (configured == null) {
      throw CfvmException(
        'No Flutter version configured.',
        hint: 'Run "$cliName use <version>" in your project, '
            'or "$cliName global <version>" to set a default.',
      );
    }
    return configured;
  }
}
