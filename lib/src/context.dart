import 'dart:io';

import 'config/global_config.dart';
import 'io/logger.dart';
import 'io/process_runner.dart';
import 'io/prompter.dart';
import 'platform.dart';
import 'releases/flutter_releases.dart';
import 'sdk/cfvm_home.dart';
import 'sdk/sdk_cache.dart';
import 'sdk/sdk_installer.dart';
import 'sdk/version_resolver.dart';

/// Everything a command needs, bundled so tests can substitute fakes.
class CfvmContext {
  CfvmContext({
    required this.home,
    required this.host,
    required this.workingDirectory,
    required this.logger,
    required this.prompter,
    required this.releases,
    required this.processRunner,
    required this.environment,
    SdkInstaller? installer,
  })  : cache = SdkCache(home, host),
        installer = installer ??
            IoSdkInstaller(
              home: home,
              host: host,
              logger: logger,
              processRunner: processRunner,
              environment: environment,
            );

  factory CfvmContext.production() {
    final host = HostPlatform.current();
    final environment = Platform.environment;
    return CfvmContext(
      home: CfvmHome.fromEnvironment(environment, isWindows: host.isWindows),
      host: host,
      workingDirectory: Directory.current.path,
      logger: Logger(),
      prompter: StdioPrompter(),
      releases: HttpReleaseRepository(host),
      processRunner: IoProcessRunner(),
      environment: environment,
    );
  }

  final CfvmHome home;
  final HostPlatform host;
  final String workingDirectory;
  final Logger logger;
  final Prompter prompter;
  final ReleaseRepository releases;
  final ProcessRunner processRunner;
  final Map<String, String> environment;
  final SdkCache cache;
  final SdkInstaller installer;

  late final VersionResolver resolver =
      VersionResolver(home: home, host: host, cache: cache, releases: releases);

  GlobalConfig loadGlobalConfig() => GlobalConfig.load(home.configPath);

  void saveGlobalConfig(GlobalConfig config) => config.save(home.configPath);
}
