import '../errors.dart';
import '../version.dart';
import 'json_file.dart';

/// CFVM-wide settings stored in `<CFVM_HOME>/config.json`:
///
/// ```json
/// {
///   "globalVersion": "3.19.0",
///   "projects": ["/path/to/app"]
/// }
/// ```
///
/// `projects` records directories where `cfvm use` was run, so `cleanup`
/// knows which installed versions are still referenced.
class GlobalConfig {
  GlobalConfig({this.globalVersion, List<String>? projects})
      : projects = projects ?? [];

  factory GlobalConfig.load(String path) {
    final json = readJsonObject(path);
    if (json == null) return GlobalConfig();
    final version = json['globalVersion'];
    final projects = json['projects'];
    if ((version != null && version is! String) ||
        (projects != null &&
            (projects is! List || projects.any((e) => e is! String)))) {
      throw CfvmException(
        'Invalid CFVM config at $path.',
        hint: 'Fix or delete the file and try again.',
      );
    }
    if (version != null) validateVersionName(version as String);
    return GlobalConfig(
      globalVersion: version as String?,
      projects: projects == null ? null : List<String>.from(projects as List),
    );
  }

  String? globalVersion;
  final List<String> projects;

  void addProject(String directory) {
    if (!projects.contains(directory)) projects.add(directory);
  }

  void save(String path) {
    writeJsonObject(path, {
      if (globalVersion != null) 'globalVersion': globalVersion,
      'projects': projects,
    });
  }
}
