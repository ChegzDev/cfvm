import 'dart:convert';
import 'dart:io';

import 'package:cfvm/src/cli/runner.dart';
import 'package:cfvm/src/config/global_config.dart';
import 'package:cfvm/src/config/project_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());

  Future<int> run(List<String> args, {String? cwd}) =>
      CfvmCommandRunner(env.context(workingDirectory: cwd)).run(args);

  GlobalConfig global() => GlobalConfig.load(env.home.configPath);

  test('unknown commands and bad arguments are usage errors', () async {
    expect(await run(['nope']), 64);
    expect(await run(['use']), 64);
    expect(await run(['use', 'a', 'b']), 64);
  });

  group('install', () {
    test('installs a version from release metadata', () async {
      expect(await run(['install', '3.19.0']), 0);
      expect(env.installer.installed, ['3.19.0']);
    });

    test('resolves channels to the current release', () async {
      expect(await run(['install', 'stable']), 0);
      expect(env.installer.installed, ['3.22.1']);
    });

    test('installs master with git', () async {
      expect(await run(['install', 'master']), 0);
      expect(env.installer.installed, ['master']);
    });

    test('skips versions that are already installed', () async {
      createFakeSdk(env.home, '3.19.0');
      expect(await run(['install', '3.19.0']), 0);
      expect(env.installer.installed, isEmpty);
      expect(env.releases.fetchCount, 0);
      expect(env.out.toString(), contains('already installed'));
    });

    test('without a version installs the project version', () async {
      ProjectConfig.save(env.projectDir.path, '3.19.0');
      expect(await run(['install']), 0);
      expect(env.installer.installed, ['3.19.0']);
    });

    test('does not delete an incomplete install without confirmation',
        () async {
      final dir = Directory(env.home.versionDir('3.19.0'))
        ..createSync(recursive: true);
      expect(await run(['install', '3.19.0']), 1);
      expect(dir.existsSync(), isTrue);
      expect(env.installer.installed, isEmpty);
    });

    test('replaces an incomplete install when confirmed', () async {
      env.dispose();
      env = TestEnv(interactive: true, answers: ['y']);
      Directory(env.home.versionDir('3.19.0')).createSync(recursive: true);
      expect(await run(['install', '3.19.0']), 0);
      expect(env.installer.installed, ['3.19.0']);
    });
  });

  group('use', () {
    test('writes the project config and tracks the project', () async {
      createFakeSdk(env.home, '3.19.0');
      final nested = Directory(p.join(env.projectDir.path, 'lib'))
        ..createSync();
      expect(await run(['use', '3.19.0'], cwd: nested.path), 0);

      final file = File(p.join(env.projectDir.path, '.cfvm.json'));
      expect(jsonDecode(file.readAsStringSync()), {'flutter': '3.19.0'});
      expect(global().projects.single, p.normalize(env.projectDir.path));
    });

    test('installs a missing version first, then sets it', () async {
      expect(await run(['use', '3.19.0']), 0);
      expect(env.installer.installed, ['3.19.0']);
      final file = File(p.join(env.projectDir.path, '.cfvm.json'));
      expect(jsonDecode(file.readAsStringSync()), {'flutter': '3.19.0'});
      expect(env.out.toString(), contains('installed successfully'));
    });

    test('does not install again when already installed', () async {
      createFakeSdk(env.home, '3.19.0');
      expect(await run(['use', '3.19.0']), 0);
      expect(env.installer.installed, isEmpty);
      expect(env.releases.fetchCount, 0);
    });

    test('pins the exact release for a channel', () async {
      expect(await run(['use', 'stable']), 0);
      final file = File(p.join(env.projectDir.path, '.cfvm.json'));
      expect(jsonDecode(file.readAsStringSync()), {'flutter': '3.22.1'});
    });

    test('writes nothing for an unknown version', () async {
      expect(await run(['use', '9.9.9']), 1);
      expect(env.err.toString(), contains('not found'));
      expect(env.installer.installed, isEmpty);
      expect(File(p.join(env.projectDir.path, '.cfvm.json')).existsSync(),
          isFalse);
    });
  });

  group('global', () {
    test('sets and shows the global version', () async {
      createFakeSdk(env.home, '3.19.0');
      expect(await run(['global', '3.19.0']), 0);
      expect(global().globalVersion, '3.19.0');

      expect(await run(['global']), 0);
      expect(env.out.toString(), contains('Global Flutter version: 3.19.0'));
    });

    test('installs a missing version first, then sets it', () async {
      expect(await run(['global', '3.19.0']), 0);
      expect(env.installer.installed, ['3.19.0']);
      expect(global().globalVersion, '3.19.0');
    });

    test('leaves the global version unchanged for an unknown version',
        () async {
      expect(await run(['global', '9.9.9']), 1);
      expect(global().globalVersion, isNull);
    });
  });

  group('list', () {
    test('marks project and global versions', () async {
      createFakeSdk(env.home, '3.19.0');
      createFakeSdk(env.home, '3.22.1');
      GlobalConfig(globalVersion: '3.19.0').save(env.home.configPath);
      ProjectConfig.save(env.projectDir.path, '3.22.1');

      expect(await run(['list']), 0);
      final out = env.out.toString();
      expect(out, contains('3.22.1  (project)'));
      expect(out, contains('3.19.0  (global)'));
      expect(out.indexOf('3.22.1'), lessThan(out.indexOf('3.19.0')));
    });

    test('explains how to install when empty', () async {
      expect(await run(['list']), 0);
      expect(env.out.toString(), contains('No Flutter SDKs installed'));
    });
  });

  group('cleanup', () {
    setUp(() {
      createFakeSdk(env.home, '3.19.0'); // global
      createFakeSdk(env.home, '3.22.1'); // used by a tracked project
      createFakeSdk(env.home, '3.3.10'); // unused
      final other = Directory(p.join(env.root.path, 'other'))..createSync();
      ProjectConfig.save(other.path, '3.22.1');
      (GlobalConfig(globalVersion: '3.19.0')
            ..addProject(other.path)
            ..addProject(p.join(env.root.path, 'deleted')))
          .save(env.home.configPath);
    });

    bool installed(String v) => Directory(env.home.versionDir(v)).existsSync();

    test('never deletes when not interactive and --yes is missing', () async {
      expect(await run(['cleanup']), 0);
      expect(installed('3.3.10'), isTrue);
      expect(env.out.toString(), contains('cleanup --yes'));
    });

    test('--yes removes only unused versions', () async {
      expect(await run(['cleanup', '--yes']), 0);
      expect(installed('3.3.10'), isFalse);
      expect(installed('3.19.0'), isTrue);
      expect(installed('3.22.1'), isTrue);
      // Projects that no longer exist are forgotten.
      expect(global().projects, hasLength(1));
    });

    test('declining at the prompt removes nothing', () async {
      env.dispose();
      env = TestEnv(interactive: true, answers: ['n']);
      createFakeSdk(env.home, '3.3.10');
      expect(await run(['cleanup']), 0);
      expect(installed('3.3.10'), isTrue);
      expect(env.out.toString(), contains('Nothing removed'));
    });

    test('also removes leftovers of interrupted installs', () async {
      final staging = Directory(env.home.stagingDir('3.24.0'))
        ..createSync(recursive: true);
      final temp = Directory(env.home.tempDir)..createSync(recursive: true);
      File(p.join(temp.path, 'x.zip.part')).writeAsStringSync('partial');
      expect(await run(['cleanup']), 0);
      expect(staging.existsSync(), isFalse);
      expect(temp.existsSync(), isFalse);
    });
  });

  group('interactive cleanup', () {
    test('select mode asks per version', () async {
      env.dispose();
      env = TestEnv(interactive: true, answers: ['s', 'y', 'n']);
      createFakeSdk(env.home, '3.22.1');
      createFakeSdk(env.home, '3.19.0');
      expect(await run(['cleanup']), 0);
      expect(Directory(env.home.versionDir('3.22.1')).existsSync(), isFalse);
      expect(Directory(env.home.versionDir('3.19.0')).existsSync(), isTrue);
    });
  });

  group('flutter / dart', () {
    test('run the selected SDK and pass all arguments through', () async {
      createFakeSdk(env.home, '3.19.0');
      ProjectConfig.save(env.projectDir.path, '3.19.0');
      env.processRunner.exitCode = 3;

      expect(await run(['flutter', 'build', 'apk', '--release', '-h']), 3);
      expect(await run(['dart', 'pub', 'get']), 3);

      final sdkBin = p.join(env.home.versionDir('3.19.0'), 'bin');
      final flutterRun = env.processRunner.runs[0];
      expect(flutterRun.executable, p.join(sdkBin, 'flutter'));
      expect(flutterRun.arguments, ['build', 'apk', '--release', '-h']);
      expect(flutterRun.environment!['PATH'], '$sdkBin:/usr/bin');

      final dartRun = env.processRunner.runs[1];
      expect(dartRun.executable, p.join(sdkBin, 'dart'));
      expect(dartRun.arguments, ['pub', 'get']);
    });

    test('fail with a hint when the SDK is missing', () async {
      ProjectConfig.save(env.projectDir.path, '3.19.0');
      expect(await run(['flutter', 'doctor']), 1);
      expect(env.processRunner.runs, isEmpty);
      expect(env.out.toString(), contains('install 3.19.0'));
    });
  });
}
