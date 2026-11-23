@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:cfvm/src/errors.dart';
import 'package:cfvm/src/io/logger.dart';
import 'package:cfvm/src/io/process_runner.dart';
import 'package:cfvm/src/releases/flutter_releases.dart';
import 'package:cfvm/src/sdk/cfvm_home.dart';
import 'package:cfvm/src/sdk/sdk_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers.dart';

/// Exercises the real download -> verify -> extract -> rename pipeline
/// against a local HTTP server serving a tiny fake SDK archive.
void main() {
  late Directory tmp;
  late HttpServer server;
  late List<int> archiveBytes;
  late IoSdkInstaller installer;
  late CfvmHome home;

  final hasZip = Process.runSync('which', ['zip']).exitCode == 0 &&
      Process.runSync('which', ['unzip']).exitCode == 0;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cfvm_install_');
    final src = Directory(p.join(tmp.path, 'src', 'flutter', 'bin'))
      ..createSync(recursive: true);
    File(p.join(src.path, 'flutter')).writeAsStringSync('#!/bin/sh\n');
    final zip = p.join(tmp.path, 'sdk.zip');
    Process.runSync('zip', ['-qr', zip, 'flutter'],
        workingDirectory: p.join(tmp.path, 'src'));
    archiveBytes = File(zip).readAsBytesSync();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.contentLength = archiveBytes.length;
      request.response.add(archiveBytes);
      request.response.close();
    });

    home = CfvmHome(p.join(tmp.path, 'home'));
    installer = IoSdkInstaller(
      home: home,
      host: linuxX64,
      logger: Logger(out: StringBuffer(), err: StringBuffer()),
      processRunner: IoProcessRunner(),
    );
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  FlutterRelease release(String sha) => FlutterRelease(
        hash: 'h',
        channel: 'stable',
        version: '3.19.0',
        archive: 'stable/linux/flutter_3.19.0-stable.zip',
        sha256: sha,
      );

  String baseUrl() => 'http://127.0.0.1:${server.port}';

  bool hasLeftovers() =>
      Directory(home.versionsDir).existsSync() &&
          Directory(home.versionsDir)
              .listSync()
              .any((e) => p.basename(e.path).startsWith('.')) ||
      (Directory(home.tempDir).existsSync() &&
          Directory(home.tempDir).listSync().isNotEmpty);

  test('installs a verified archive atomically', () async {
    await installer.installRelease(
        release(sha256.convert(archiveBytes).toString()),
        baseUrl: baseUrl());
    expect(
        File(p.join(home.versionDir('3.19.0'), 'bin', 'flutter')).existsSync(),
        isTrue);
    expect(hasLeftovers(), isFalse);
    expect(Directory(home.tempDir).existsSync(), isFalse);
  }, skip: hasZip ? false : 'zip/unzip not available');

  test('rejects a checksum mismatch and leaves nothing behind', () async {
    await expectLater(
      installer.installRelease(release('0' * 64), baseUrl: baseUrl()),
      throwsA(isA<CfvmException>()
          .having((e) => e.message, 'message', contains('Checksum'))),
    );
    expect(Directory(home.versionDir('3.19.0')).existsSync(), isFalse);
    expect(hasLeftovers(), isFalse);
  }, skip: hasZip ? false : 'zip/unzip not available');

  test('refuses to overwrite an existing SDK directory', () async {
    createFakeSdk(home, '3.19.0');
    await expectLater(
      installer.installRelease(release('x'), baseUrl: baseUrl()),
      throwsA(isA<CfvmException>()),
    );
    expect(
        File(p.join(home.versionDir('3.19.0'), 'bin', 'flutter')).existsSync(),
        isTrue);
  });
}
