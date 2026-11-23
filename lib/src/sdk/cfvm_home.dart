import 'package:path/path.dart' as p;

import '../errors.dart';

/// Layout of the CFVM-managed directory (default `~/cfvm`, overridable
/// with the `CFVM_HOME` environment variable):
///
/// ```
/// ~/cfvm/
///   config.json            global settings
///   versions/<version>/    installed Flutter SDKs
///   tmp/                   in-progress downloads and extractions
/// ```
class CfvmHome {
  CfvmHome(String root) : root = p.normalize(p.absolute(root));

  factory CfvmHome.fromEnvironment(
    Map<String, String> environment, {
    required bool isWindows,
  }) {
    final override = environment['CFVM_HOME'];
    if (override != null && override.isNotEmpty) return CfvmHome(override);
    final home = isWindows ? environment['USERPROFILE'] : environment['HOME'];
    if (home == null || home.isEmpty) {
      throw const CfvmException(
        'Could not determine your home directory.',
        hint: 'Set the CFVM_HOME environment variable.',
      );
    }
    return CfvmHome(p.join(home, 'cfvm'));
  }

  final String root;

  String get configPath => p.join(root, 'config.json');
  String get versionsDir => p.join(root, 'versions');
  String get tempDir => p.join(root, 'tmp');

  String versionDir(String version) => p.join(versionsDir, version);

  /// Extraction happens here. It is inside [root], on the same filesystem as
  /// [versionDir], so the finished SDK can be moved into place with an
  /// atomic rename.
  String stagingDir(String version) => p.join(tempDir, 'staging-$version');
}
