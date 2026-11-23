import 'package:cfvm/src/cli/runner.dart';
import 'package:cfvm/src/cli_name.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('detectCliName', () {
    test('global activation (pub cache global_packages) -> cfvm', () {
      expect(
          detectCliName(p.join('home', '.pub-cache', 'global_packages', 'cfvm',
              'bin', 'cfvm.dart-3.14.0.snapshot')),
          'cfvm');
    });

    test('dart run from a project or the repository -> dart run cfvm', () {
      expect(
          detectCliName(p.join('app', '.dart_tool', 'pub', 'bin', 'cfvm',
              'cfvm.dart-3.14.0.snapshot')),
          'dart run cfvm');
      expect(detectCliName(p.join('src', 'cfvm', 'bin', 'cfvm.dart')),
          'dart run cfvm');
    });
  });

  group('hints follow the detected name', () {
    late TestEnv env;
    late String original;

    setUp(() {
      original = cliName;
      env = TestEnv();
    });
    tearDown(() {
      cliName = original;
      env.dispose();
    });

    Future<int> run(List<String> args) =>
        CfvmCommandRunner(env.context()).run(args);

    test('global install shows cfvm commands', () async {
      cliName = 'cfvm';
      expect(await run(['flutter', 'doctor']), 1);
      expect(env.out.toString(), contains('Run "cfvm use <version>"'));
      expect(env.out.toString(), isNot(contains('dart run')));
    });

    test('dart run shows dart run cfvm commands', () async {
      cliName = 'dart run cfvm';
      expect(await run(['flutter', 'doctor']), 1);
      expect(env.out.toString(), contains('Run "dart run cfvm use <version>"'));
    });

    test('usage text uses the detected name', () async {
      cliName = 'cfvm';
      expect(await run(['nope']), 64);
      expect(env.out.toString(), contains('Usage: cfvm <command>'));
    });
  });
}
