// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file_testing/file_testing.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:process/process.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../src/common.dart';

const String apkDebugMessage = 'A summary of your APK analysis can be found at: ';
const String iosDebugMessage = 'A summary of your iOS bundle analysis can be found at: ';

void main() {
  test('--analyze-size flag produces expected output on hello_world for Android', () async {
    final String flutterBin = globals.fs.path.join(getFlutterRoot(), 'bin', 'flutter');
    final ProcessResult result = await const LocalProcessManager().run(<String>[
      flutterBin,
      'build',
      'apk',
      '--analyze-size',
      '--target-platform=android-arm64'
    ], workingDirectory: globals.fs.path.join(getFlutterRoot(), 'examples', 'hello_world'));

    print(result.stdout);
    print(result.stderr);
    expect(result.stdout.toString(), contains('app-release.apk (total compressed)'));

    final String line = result.stdout.toString()
      .split('\n')
      .firstWhere((String line) => line.contains(apkDebugMessage));

    expect(globals.fs.file(globals.fs.path.join(line.split(apkDebugMessage).last.trim())), exists);
    expect(result.exitCode, 0);
  }, skip: const LocalPlatform().isWindows); // Not yet supported on Windows

  test('--analyze-size flag produces expected output on hello_world for iOS', () async {
    final String flutterBin = globals.fs.path.join(getFlutterRoot(), 'bin', 'flutter');
    final ProcessResult result = await const LocalProcessManager().run(<String>[
      flutterBin,
      'build',
      'ios',
      '--analyze-size',
    ], workingDirectory: globals.fs.path.join(getFlutterRoot(), 'examples', 'hello_world'));

    print(result.stdout);
    print(result.stderr);
    expect(result.stdout.toString(), contains('Runner.app/Frameworks/App.framework/App (Dart AOT)'));

    final String line = result.stdout.toString()
      .split('\n')
      .firstWhere((String line) => line.contains(iosDebugMessage));

    expect(globals.fs.file(globals.fs.path.join(line.split(iosDebugMessage).last.trim())).existsSync(), true);
    expect(result.exitCode, 0);
  }, skip: !const LocalPlatform().isMacOS); // Only supported on macOS
}
