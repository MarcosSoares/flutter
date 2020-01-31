// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/dart.dart';
import 'package:flutter_tools/src/build_system/targets/font_subset.dart';
import 'package:flutter_tools/src/devfs.dart';
import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';

import '../../../src/common.dart';
import '../../../src/context.dart';
import '../../../src/mocks.dart' as mocks;

final Platform _kNoAnsiPlatform =
    FakePlatform.fromPlatform(const LocalPlatform())
      ..stdoutSupportsAnsi = false;

void main() {
  BufferLogger logger;
  MemoryFileSystem fs;
  MockProcessManager mockProcessManager;
  MockProcess fontSubsetProcess;
  MockArtifacts mockArtifacts;
  DevFSStringContent fontManifestContent;

  const String dartPath = '/flutter/dart';
  const String constFinderPath = '/flutter/const_finder.snapshot.dart';
  const String fontSubsetPath = '/flutter/font-subset';

  const String inputPath = '/input/fonts/MaterialIcons-Regular.ttf';
  const String outputPath = '/output/fonts/MaterialIcons-Regular.ttf';
  const String relativePath = 'fonts/MaterialIcons-Regular.ttf';

  List<String> getConstFinderArgs(String appDillPath) => <String>[
    dartPath,
    constFinderPath,
    '--kernel-file', appDillPath,
    '--class-library-uri', 'package:flutter/src/widgets/icon_data.dart',
    '--class-name', 'IconData',
  ];

  const List<String> fontSubsetArgs = <String>[
    fontSubsetPath,
    outputPath,
    inputPath,
  ];

  void _addConstFinderInvocation(
    String appDillPath, {
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
  }) {
    when(mockProcessManager.run(getConstFinderArgs(appDillPath))).thenAnswer((_) async {
      return ProcessResult(0, exitCode, stdout, stderr);
    });
  }

  void _resetFontSubsetInvocation({
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
    @required List<String> stdinResults,
  }) {
    assert(stdinResults != null);
    stdinResults.clear();
    final IOSink sink = IOSink(StringStreamConsumer(stdinResults));
    when(fontSubsetProcess.exitCode).thenAnswer((_) async => exitCode);
    when(fontSubsetProcess.stdout).thenAnswer((_) => Stream<List<int>>.fromIterable(<List<int>>[utf8.encode(stdout)]));
    when(fontSubsetProcess.stderr).thenAnswer((_) => Stream<List<int>>.fromIterable(<List<int>>[utf8.encode(stderr)]));
    when(fontSubsetProcess.stdin).thenReturn(sink);
    when(mockProcessManager.start(fontSubsetArgs)).thenAnswer((_) async {
      return fontSubsetProcess;
    });
  }

  setUp(() {
    fontManifestContent = DevFSStringContent(validFontManifestJson);

    mockProcessManager = MockProcessManager();
    fontSubsetProcess = MockProcess();
    mockArtifacts = MockArtifacts();

    fs = MemoryFileSystem();
    logger = BufferLogger(
      terminal: AnsiTerminal(
        stdio: mocks.MockStdio(),
        platform: _kNoAnsiPlatform,
      ),
      outputPreferences: OutputPreferences.test(showColor: false),
    );

    fs.file(constFinderPath).createSync(recursive: true);
    fs.file(dartPath).createSync(recursive: true);
    fs.file(fontSubsetPath).createSync(recursive: true);
    when(mockArtifacts.getArtifactPath(Artifact.constFinder)).thenReturn(constFinderPath);
    when(mockArtifacts.getArtifactPath(Artifact.fontSubset)).thenReturn(fontSubsetPath);
    when(mockArtifacts.getArtifactPath(Artifact.engineDartBinary)).thenReturn(dartPath);
  });

  Environment _createEnvironment(Map<String, String> defines) {
    return Environment(
      cacheDir: fs.directory('/build/cache')..createSync(recursive: true),
      flutterRootDir: fs.directory('/flutter')..createSync(recursive: true),
      outputDir: fs.directory('/build/output')..createSync(recursive: true),
      projectDir: fs.directory('/project')..createSync(recursive: true),
      buildDir: fs.directory('/build')..createSync(recursive: true),
      defines: defines,
    );
  }

  test('Prints error in debug mode environment', () async {
    final Environment environment = _createEnvironment(<String, String>{
      kFontSubsetFlag: 'true',
      kBuildMode: 'debug',
    });

    final FontSubset fontSubset = FontSubset(
      environment,
      fontManifestContent,
      logger: logger,
      processManager: mockProcessManager,
      fs: fs,
      artifacts: mockArtifacts,
    );

    expect(
      logger.errorText,
      'Font subetting is not supported in debug mode. The --tree-shake-icons flag will be ignored.\n',
    );
    expect(fontSubset.enabled, false);

    final bool subsets = await fontSubset.subsetFont(
      inputPath: inputPath,
      outputPath: outputPath,
      relativePath: relativePath,
    );
    expect(subsets, false);

    verifyNever(mockProcessManager.run(any));
    verifyNever(mockProcessManager.start(any));
  });

  test('Gets enabled', () {
    final Environment environment = _createEnvironment(<String, String>{
      kFontSubsetFlag: 'true',
      kBuildMode: 'release',
    });

    final FontSubset fontSubset = FontSubset(
      environment,
      fontManifestContent,
      logger: logger,
      processManager: mockProcessManager,
      fs: fs,
      artifacts: mockArtifacts,
    );

    expect(
      logger.errorText,
      isEmpty,
    );
    expect(fontSubset.enabled, true);
    verifyNever(mockProcessManager.run(any));
    verifyNever(mockProcessManager.start(any));
  });

  test('No app.dill throws exception', () async {
    final Environment environment = _createEnvironment(<String, String>{
      kFontSubsetFlag: 'true',
      kBuildMode: 'release',
    });

    final FontSubset fontSubset = FontSubset(
      environment,
      fontManifestContent,
      logger: logger,
      processManager: mockProcessManager,
      fs: fs,
      artifacts: mockArtifacts,
    );

    expect(
      () => fontSubset.subsetFont(
        inputPath: inputPath,
        outputPath: outputPath,
        relativePath: relativePath,
      ),
      throwsA(isA<FontSubsetException>()),
    );
  });

  test('The happy path', () async {
    final Environment environment = _createEnvironment(<String, String>{
      kFontSubsetFlag: 'true',
      kBuildMode: 'release',
    });
    final File appDill = environment.buildDir.childFile('app.dill')..createSync(recursive: true);
    fs.file(inputPath).createSync(recursive: true);

    final FontSubset fontSubset = FontSubset(
      environment,
      fontManifestContent,
      logger: logger,
      processManager: mockProcessManager,
      fs: fs,
      artifacts: mockArtifacts,
    );

    final List<String> stdinResults = <String>[];
    _addConstFinderInvocation(appDill.path, stdout: validConstFinderResult);
    _resetFontSubsetInvocation(stdinResults: stdinResults);

    bool subsetted = await fontSubset.subsetFont(
      inputPath: inputPath,
      outputPath: outputPath,
      relativePath: relativePath,
    );
    expect(stdinResults, <String>['59470', '\n']);
    _resetFontSubsetInvocation(stdinResults: stdinResults);

    expect(subsetted, true);
    subsetted = await fontSubset.subsetFont(
      inputPath: inputPath,
      outputPath: outputPath,
      relativePath: relativePath,
    );
    expect(subsetted, true);
    expect(stdinResults, <String>['59470', '\n']);

    verify(mockProcessManager.run(getConstFinderArgs(appDill.path))).called(1);
    verify(mockProcessManager.start(fontSubsetArgs)).called(2);
  });

  test('Non-constant instances', () async {
    final Environment environment = _createEnvironment(<String, String>{
      kFontSubsetFlag: 'true',
      kBuildMode: 'release',
    });
    final File appDill = environment.buildDir.childFile('app.dill')..createSync(recursive: true);
    fs.file(inputPath).createSync(recursive: true);

    final FontSubset fontSubset = FontSubset(
      environment,
      fontManifestContent,
      logger: logger,
      processManager: mockProcessManager,
      fs: fs,
      artifacts: mockArtifacts,
    );

    _addConstFinderInvocation(appDill.path, stdout: constFinderResultWithInvalid);

    expect(
      fontSubset.subsetFont(
        inputPath: inputPath,
        outputPath: outputPath,
        relativePath: relativePath,
      ),
      throwsToolExit(
        message: 'Avoid non-constant invocations of IconData or try to build again with --no-tree-shake-icons.',
      ),
    );

    verify(mockProcessManager.run(getConstFinderArgs(appDill.path))).called(1);
    verifyNever(mockProcessManager.start(fontSubsetArgs));
  });

  test('Invalid font manifest', () async {
    final Environment environment = _createEnvironment(<String, String>{
      kFontSubsetFlag: 'true',
      kBuildMode: 'release',
    });
    final File appDill = environment.buildDir.childFile('app.dill')..createSync(recursive: true);
    fs.file(inputPath).createSync(recursive: true);

    fontManifestContent = DevFSStringContent(invalidFontManifestJson);

    final FontSubset fontSubset = FontSubset(
      environment,
      fontManifestContent,
      logger: logger,
      processManager: mockProcessManager,
      fs: fs,
      artifacts: mockArtifacts,
    );

    _addConstFinderInvocation(appDill.path, stdout: validConstFinderResult);

    expect(
      fontSubset.subsetFont(
        inputPath: inputPath,
        outputPath: outputPath,
        relativePath: relativePath,
      ),
      throwsA(isA<FontSubsetException>()),
    );

    verify(mockProcessManager.run(getConstFinderArgs(appDill.path))).called(1);
    verifyNever(mockProcessManager.start(fontSubsetArgs));
  });

}

const String validConstFinderResult = '''
{
  "constantInstances": [
    {
      "codePoint": 59470,
      "fontFamily": "MaterialIcons",
      "fontPackage": null,
      "matchTextDirection": false
    }
  ],
  "nonConstantLocations": []
}
''';

const String constFinderResultWithInvalid = '''
{
  "constantInstances": [
    {
      "codePoint": 59470,
      "fontFamily": "MaterialIcons",
      "fontPackage": null,
      "matchTextDirection": false
    }
  ],
  "nonConstantLocations": [
    {
      "file": "file:///Path/to/hello_world/lib/file.dart",
      "line": 19,
      "column": 11
    }
  ]
}
''';

const String validFontManifestJson = '''
[
  {
    "family": "MaterialIcons",
    "fonts": [
      {
        "asset": "fonts/MaterialIcons-Regular.ttf"
      }
    ]
  },
  {
    "family": "GalleryIcons",
    "fonts": [
      {
        "asset": "packages/flutter_gallery_assets/fonts/private/gallery_icons/GalleryIcons.ttf"
      }
    ]
  },
  {
    "family": "packages/cupertino_icons/CupertinoIcons",
    "fonts": [
      {
        "asset": "packages/cupertino_icons/assets/CupertinoIcons.ttf"
      }
    ]
  }
]
''';

const String invalidFontManifestJson = '''
{
  "famly": "MaterialIcons",
  "fonts": [
    {
      "asset": "fonts/MaterialIcons-Regular.ttf"
    }
  ]
}
''';

class MockProcessManager extends Mock implements ProcessManager {}
class MockProcess extends Mock implements Process {}
class MockArtifacts extends Mock implements Artifacts {}

/// A stream consumer class that consumes UTF8 strings as lists of ints.
class StringStreamConsumer implements StreamConsumer<List<int>> {
  StringStreamConsumer(this.strings) : assert(strings != null);

  List<Stream<List<int>>> streams = <Stream<List<int>>>[];
  List<StreamSubscription<List<int>>> subscriptions = <StreamSubscription<List<int>>>[];
  List<Completer<dynamic>> completers = <Completer<dynamic>>[];

  List<String> strings;

  @override
  Future<dynamic> addStream(Stream<List<int>> value) {
    streams.add(value);
    completers.add(Completer<dynamic>());
    subscriptions.add(
      value.listen((List<int> data) {
        strings.add(utf8.decode(data));
      }),
    );
    subscriptions.last.onDone(() => completers.last.complete(null));
    return Future<dynamic>.value(null);
  }

  @override
  Future<dynamic> close() async {
    for (final Completer<dynamic> completer in completers) {
      await completer.future;
    }
    completers.clear();
    streams.clear();
    subscriptions.clear();
    return Future<dynamic>.value(null);
  }
}
