import 'dart:io';

import 'package:cfvm/src/errors.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  test('returns installed versions without network access', () async {
    createFakeSdk(env.home, '3.19.0');
    final result = await env.context().provisioner.ensureInstalled('v3.19.0');
    expect(result.name, '3.19.0');
    expect(result.newlyInstalled, isFalse);
    expect(env.releases.fetchCount, 0);
    expect(env.installer.installed, isEmpty);
  });

  test('installs a missing version', () async {
    final result = await env.context().provisioner.ensureInstalled('3.19.0');
    expect(result.name, '3.19.0');
    expect(result.newlyInstalled, isTrue);
    expect(env.installer.installed, ['3.19.0']);
  });

  test('resolves a channel to its current release', () async {
    final result = await env.context().provisioner.ensureInstalled('stable');
    expect(result.label, '3.22.1 (current stable)');
    expect(env.installer.installed, ['3.22.1']);

    final again = await env.context().provisioner.ensureInstalled('stable');
    expect(again.newlyInstalled, isFalse);
    expect(env.installer.installed, ['3.22.1']);
  });

  test('installs master with git', () async {
    final result = await env.context().provisioner.ensureInstalled('master');
    expect(result.name, 'master');
    expect(env.installer.installed, ['master']);
    expect(env.releases.fetchCount, 0);
  });

  test('rejects unknown and invalid versions without installing', () {
    final provisioner = env.context().provisioner;
    expect(provisioner.ensureInstalled('9.9.9'), throwsA(isA<CfvmException>()));
    expect(provisioner.ensureInstalled('../x'), throwsA(isA<CfvmException>()));
    expect(env.installer.installed, isEmpty);
  });

  test('never replaces an incomplete install without confirmation', () async {
    final dir = Directory(env.home.versionDir('3.19.0'))
      ..createSync(recursive: true);
    await expectLater(env.context().provisioner.ensureInstalled('3.19.0'),
        throwsA(isA<CfvmException>()));
    expect(dir.existsSync(), isTrue);
    expect(env.installer.installed, isEmpty);
  });

  test('replaces an incomplete install when confirmed', () async {
    env.dispose();
    env = TestEnv(interactive: true, answers: ['y']);
    Directory(env.home.versionDir('3.19.0')).createSync(recursive: true);
    final result = await env.context().provisioner.ensureInstalled('3.19.0');
    expect(result.newlyInstalled, isTrue);
    expect(env.installer.installed, ['3.19.0']);
  });
}
