import 'dart:convert';
import 'dart:io';

import '../errors.dart';

/// Reads a JSON object from [path], or returns null if the file is missing.
Map<String, dynamic>? readJsonObject(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Reported below.
  }
  throw CfvmException(
    'Could not parse $path: expected a JSON object.',
    hint: 'Fix or delete the file and try again.',
  );
}

/// Writes [data] as pretty-printed JSON. Writes to a temporary file first and
/// renames it, so an interrupted write never leaves a half-written file.
void writeJsonObject(String path, Map<String, dynamic> data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  final temp = File('$path.tmp');
  temp.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n');
  temp.renameSync(path);
}
