import 'package:path/path.dart' as p;

/// How the user invokes CFVM (`cfvm` or `dart run cfvm`). Used in help text
/// and hints so they can be copied as-is. Set once at startup from
/// [detectCliName].
String cliName = 'dart run cfvm';

/// `dart pub global activate cfvm` runs CFVM from the pub cache's
/// `global_packages` directory, where the `cfvm` command is available.
/// Anything else (`dart run cfvm` in a project or in this repository) gets
/// the `dart run cfvm` form.
String detectCliName(String scriptPath) =>
    p.split(scriptPath).contains('global_packages') ? 'cfvm' : 'dart run cfvm';
