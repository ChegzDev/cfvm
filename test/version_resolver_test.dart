import 'package:cfvm/src/config/global_config.dart';
import 'package:cfvm/src/config/project_config.dart';
import 'package:cfvm/src/errors.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  group('configuredVersion', () {
    test('is null when nothing is configured', () {
      expect(env.context().resolver.configuredVersion(env.projectDir.path),
          isNull);
    });

    test('falls back to the global version', () {
      GlobalConfig(globalVersion: '3.19.0').save(env.home.configPath);
      final v = env.context().resolver.configuredVersion(env.projectDir.path)!;
      expect(v.version, '3.19.0');
      expect(v.isGlobal, isTrue);
    });

    test('project version takes precedence over global', () {
      GlobalConfig(globalVersion: '3.19.0').save(env.home.configPath);
      ProjectConfig.save(env.projectDir.path, '3.22.1');
      final v = env.context().resolver.configuredVersion(env.projectDir.path)!;
      expect(v.version, '3.22.1');
      expect(v.isGlobal, isFalse);
      expect(v.source, endsWith('.cfvm.json'));
    });
  });

  test('requireConfigured fails with a hint when nothing is configured', () {
    expect(
      () => env.context().resolver.requireConfigured(env.projectDir.path),
      throwsA(isA<CfvmException>()
          .having((e) => e.hint, 'hint', contains('use <version>'))),
    );
  });
}
