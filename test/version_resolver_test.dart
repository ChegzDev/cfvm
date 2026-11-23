import 'dart:io';

import 'package:cfvm/src/config/global_config.dart';
import 'package:cfvm/src/config/project_config.dart';
import 'package:cfvm/src/errors.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  group('resolveActive', () {
    test('fails with a hint when nothing is configured', () {
      expect(
        () => env.context().resolver.resolveActive(env.projectDir.path),
        throwsA(isA<CfvmException>()
            .having((e) => e.hint, 'hint', contains('use <version>'))),
      );
    });

    test('uses the global version when the project has none', () {
      createFakeSdk(env.home, '3.19.0');
      GlobalConfig(globalVersion: '3.19.0').save(env.home.configPath);
      final sdk = env.context().resolver.resolveActive(env.projectDir.path);
      expect(sdk.name, '3.19.0');
    });

    test('project version takes precedence over global', () {
      createFakeSdk(env.home, '3.19.0');
      createFakeSdk(env.home, '3.22.1');
      GlobalConfig(globalVersion: '3.19.0').save(env.home.configPath);
      ProjectConfig.save(env.projectDir.path, '3.22.1');
      final sdk = env.context().resolver.resolveActive(env.projectDir.path);
      expect(sdk.name, '3.22.1');
    });

    test('reports a configured version that is not installed', () {
      ProjectConfig.save(env.projectDir.path, '3.22.1');
      expect(
        () => env.context().resolver.resolveActive(env.projectDir.path),
        throwsA(isA<CfvmException>()
            .having((e) => e.message, 'message', contains('not installed'))
            .having((e) => e.hint, 'hint', contains('install 3.22.1'))),
      );
    });
  });

  group('resolveInstalled', () {
    test('returns installed versions without network access', () async {
      createFakeSdk(env.home, '3.19.0');
      final resolver = env.context().resolver;
      expect(await resolver.resolveInstalled('v3.19.0'), '3.19.0');
      expect(env.releases.fetchCount, 0);
    });

    test('resolves a channel to the installed current release', () async {
      createFakeSdk(env.home, '3.22.1');
      expect(await env.context().resolver.resolveInstalled('stable'), '3.22.1');
    });

    test('reports a channel whose current release is not installed', () {
      expect(
        env.context().resolver.resolveInstalled('stable'),
        throwsA(isA<CfvmException>()
            .having((e) => e.message, 'message', contains('3.22.1'))),
      );
    });

    test('reports incomplete installs', () {
      createFakeSdk(env.home, '3.19.0');
      File(env.context().cache.find('3.19.0')!.flutterExecutable).deleteSync();
      expect(
        env.context().resolver.resolveInstalled('3.19.0'),
        throwsA(isA<CfvmException>()
            .having((e) => e.message, 'message', contains('incomplete'))),
      );
    });
  });
}
