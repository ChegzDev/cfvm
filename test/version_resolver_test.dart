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
}
