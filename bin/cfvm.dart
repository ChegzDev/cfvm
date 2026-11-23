import 'dart:io';

import 'package:cfvm/cfvm.dart';

Future<void> main(List<String> arguments) async {
  final int code;
  try {
    code = await CfvmCommandRunner(CfvmContext.production()).run(arguments);
  } on CfvmException catch (e) {
    // Failures while building the context (e.g. unsupported platform).
    stderr.writeln('Error: $e');
    exitCode = 1;
    return;
  }
  exitCode = code;
}
