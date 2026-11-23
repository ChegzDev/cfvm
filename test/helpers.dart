import 'dart:io';

import 'package:cfvm/src/context.dart';
import 'package:cfvm/src/io/logger.dart';
import 'package:cfvm/src/io/process_runner.dart';
import 'package:cfvm/src/io/prompter.dart';
import 'package:cfvm/src/platform.dart';
import 'package:cfvm/src/releases/flutter_releases.dart';
import 'package:cfvm/src/sdk/cfvm_home.dart';
import 'package:cfvm/src/sdk/sdk_installer.dart';
import 'package:path/path.dart' as p;

const linuxX64 = HostPlatform('linux', 'x64');

/// Release metadata in the same shape as `releases_<os>.json`.
Map<String, dynamic> sampleMetadata() => {
      'base_url': 'https://example.com/releases',
      'current_release': {'stable': 'hash-3.22.1', 'beta': 'hash-3.23.0-0.1'},
      'releases': [
        _release('hash-3.23.0-0.1', 'beta', '3.23.0-0.1.pre', 'x64'),
        _release('hash-3.22.1', 'stable', '3.22.1', 'x64'),
        _release('hash-3.22.1', 'stable', '3.22.1', 'arm64'),
        _release('hash-3.19.0', 'stable', '3.19.0', 'x64'),
        _release('hash-1.12.13', 'stable', 'v1.12.13+hotfix.9', null),
      ],
    };

Map<String, dynamic> _release(
        String hash, String channel, String version, String? arch) =>
    {
      'hash': hash,
      'channel': channel,
      'version': version,
      if (arch != null) 'dart_sdk_arch': arch,
      'archive': '$channel/os/flutter_${arch ?? 'x64'}_$version.zip',
      'sha256': 'abc',
    };

class FakeReleaseRepository implements ReleaseRepository {
  FakeReleaseRepository([Map<String, dynamic>? metadata])
      : index = ReleaseIndex.fromJson(metadata ?? sampleMetadata());

  final ReleaseIndex index;
  int fetchCount = 0;

  @override
  Future<ReleaseIndex> fetch() async {
    fetchCount++;
    return index;
  }
}

/// Creates the SDK directory instead of downloading anything.
class FakeInstaller implements SdkInstaller {
  FakeInstaller(this.home);

  final CfvmHome home;
  final installed = <String>[];

  @override
  Future<void> installRelease(FlutterRelease release,
      {required String baseUrl}) async {
    installed.add(release.name);
    createFakeSdk(home, release.name);
  }

  @override
  Future<void> installFromGit(String channel) async {
    installed.add(channel);
    createFakeSdk(home, channel);
  }
}

class RecordedRun {
  RecordedRun(this.executable, this.arguments, this.environment);
  final String executable;
  final List<String> arguments;
  final Map<String, String>? environment;
}

class FakeProcessRunner implements ProcessRunner {
  final runs = <RecordedRun>[];
  int exitCode = 0;

  @override
  Future<int> runInteractive(String executable, List<String> arguments,
      {Map<String, String>? environment}) async {
    runs.add(RecordedRun(executable, arguments, environment));
    return exitCode;
  }

  @override
  Future<ProcessResult> runCaptured(
      String executable, List<String> arguments) async {
    runs.add(RecordedRun(executable, arguments, null));
    return ProcessResult(0, exitCode, '', '');
  }
}

class FakePrompter extends Prompter {
  FakePrompter({this.isInteractive = false, List<String>? answers})
      : answers = answers ?? [];

  @override
  final bool isInteractive;
  final List<String> answers;
  final questions = <String>[];

  @override
  String? ask(String question) {
    questions.add(question);
    return answers.isEmpty ? null : answers.removeAt(0);
  }
}

/// Creates a minimal directory that looks like an installed Flutter SDK.
void createFakeSdk(CfvmHome home, String version) {
  final bin = Directory(p.join(home.versionDir(version), 'bin'))
    ..createSync(recursive: true);
  File(p.join(bin.path, 'flutter')).writeAsStringSync('');
  File(p.join(bin.path, 'dart')).writeAsStringSync('');
}

/// A context backed by temporary directories and fakes.
class TestEnv {
  TestEnv({bool interactive = false, List<String>? answers}) {
    root = Directory.systemTemp.createTempSync('cfvm_test_');
    home = CfvmHome(p.join(root.path, 'home'));
    projectDir = Directory(p.join(root.path, 'app'))..createSync();
    File(p.join(projectDir.path, 'pubspec.yaml'))
        .writeAsStringSync('name: app');
    installer = FakeInstaller(home);
    prompter = FakePrompter(isInteractive: interactive, answers: answers);
  }

  late final Directory root;
  late final CfvmHome home;
  late final Directory projectDir;
  late final FakeInstaller installer;
  late final FakePrompter prompter;
  final releases = FakeReleaseRepository();
  final processRunner = FakeProcessRunner();
  final out = StringBuffer();
  final err = StringBuffer();

  CfvmContext context({String? workingDirectory}) => CfvmContext(
        home: home,
        host: linuxX64,
        workingDirectory: workingDirectory ?? projectDir.path,
        logger: Logger(out: out, err: err, showProgress: false),
        prompter: prompter,
        releases: releases,
        processRunner: processRunner,
        environment: const {'PATH': '/usr/bin'},
        installer: installer,
      );

  void dispose() => root.deleteSync(recursive: true);
}
