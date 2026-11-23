import 'dart:io';

import 'package:path/path.dart' as p;

import '../errors.dart';
import '../version.dart';
import 'json_file.dart';
import '../cli_name.dart';

/// The per-project Flutter version, stored in `.cfvm.json` at the project
/// root:
///
/// ```json
/// {
///   "flutter": "3.19.0"
/// }
/// ```
class ProjectConfig {
  ProjectConfig(this.directory, this.flutterVersion);

  static const fileName = '.cfvm.json';

  /// Directory containing the config file.
  final String directory;
  final String flutterVersion;

  String get filePath => p.join(directory, fileName);

  /// Loads the config in [directory], or returns null if there is none.
  static ProjectConfig? load(String directory) {
    final path = p.join(directory, fileName);
    final json = readJsonObject(path);
    if (json == null) return null;
    final version = json['flutter'];
    if (version is! String) {
      throw CfvmException(
        'Invalid $path: "flutter" must be a version string.',
        hint: 'Set it with: $cliName use <version>',
      );
    }
    final name = canonicalVersion(version);
    validateVersionName(name);
    return ProjectConfig(directory, name);
  }

  /// Finds the nearest config in [start] or any of its parent directories.
  static ProjectConfig? find(String start) {
    for (final dir in _ancestors(start)) {
      final config = load(dir);
      if (config != null) return config;
    }
    return null;
  }

  /// The directory `cfvm use` writes to: the directory of an existing config,
  /// otherwise the nearest directory with a `pubspec.yaml`, otherwise null.
  static String? findProjectRoot(String start) {
    for (final dir in _ancestors(start)) {
      if (File(p.join(dir, fileName)).existsSync()) return dir;
    }
    for (final dir in _ancestors(start)) {
      if (File(p.join(dir, 'pubspec.yaml')).existsSync()) return dir;
    }
    return null;
  }

  /// Writes [version] to the config in [directory], keeping any other keys.
  static ProjectConfig save(String directory, String version) {
    final path = p.join(directory, fileName);
    final json = readJsonObject(path) ?? <String, dynamic>{};
    json['flutter'] = version;
    writeJsonObject(path, json);
    return ProjectConfig(directory, version);
  }

  static Iterable<String> _ancestors(String start) sync* {
    var dir = p.normalize(p.absolute(start));
    while (true) {
      yield dir;
      final parent = p.dirname(dir);
      if (parent == dir) return;
      dir = parent;
    }
  }
}
