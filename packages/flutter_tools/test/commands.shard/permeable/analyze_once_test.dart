// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:platform/platform.dart';

import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/analyze.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:flutter_tools/src/runner/flutter_command_runner.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../../src/common.dart';
import '../../src/context.dart';

final Generator _kNoColorTerminalPlatform = () => FakePlatform.fromPlatform(const LocalPlatform())..stdoutSupportsAnsi = false;
final Map<Type, Generator> noColorTerminalOverride = <Type, Generator>{
  Platform: _kNoColorTerminalPlatform,
};

void main() {
  final String analyzerSeparator = globals.platform.isWindows ? '-' : '•';

  group('analyze once', () {
    setUpAll(() {
      Cache.disableLocking();
      Cache.flutterRoot = FlutterCommandRunner.defaultFlutterRoot;
    });

    void _createDotPackages(String projectPath) {
      final StringBuffer flutterRootUri = StringBuffer('file://');
      final String canonicalizedFlutterRootPath = globals.fs.path.canonicalize(Cache.flutterRoot);
      if (globals.platform.isWindows) {
        flutterRootUri
            ..write('/')
            ..write(canonicalizedFlutterRootPath.replaceAll(r'\', '/'));
      } else {
        flutterRootUri.write(canonicalizedFlutterRootPath);
      }
      final String dotPackagesSrc = '''
# Generated
flutter:$flutterRootUri/packages/flutter/lib/
sky_engine:$flutterRootUri/bin/cache/pkg/sky_engine/lib/
flutter_project:lib/
''';
      globals.fs.file(globals.fs.path.join(projectPath, '.packages'))
          ..createSync(recursive: true)
          ..writeAsStringSync(dotPackagesSrc);
    }

    group('default libMain', () {
      Directory tempDir;
      String projectPath;
      File libMain;

      setUpAll(() async {
        tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_analyze_once_test_1.').absolute;
        projectPath = globals.fs.path.join(tempDir.path, 'flutter_project');
        globals.fs.file(globals.fs.path.join(projectPath, 'pubspec.yaml'))
            ..createSync(recursive: true)
            ..writeAsStringSync(pubspecYamlSrc);
        _createDotPackages(projectPath);
      });

      setUp(() {
        libMain = globals.fs.file(globals.fs.path.join(projectPath, 'lib', 'main.dart'))
            ..createSync(recursive: true)
            ..writeAsStringSync(mainDartSrc);
      });

      tearDownAll(() {
        tryToDelete(tempDir);
      });

      // Analyze in the current directory - no arguments
      testUsingContext('working directory', () async {
        await runCommand(
          command: AnalyzeCommand(workingDirectory: globals.fs.directory(projectPath)),
          arguments: <String>['analyze', '--no-pub'],
          statusTextContains: <String>['No issues found!'],
        );
      });

      // Analyze a specific file outside the current directory
      testUsingContext('passing one file throws', () async {
        await runCommand(
          command: AnalyzeCommand(),
          arguments: <String>['analyze', '--no-pub', libMain.path],
          toolExit: true,
          exitMessageContains: 'is not a directory',
        );
      });

      // Analyze in the current directory - no arguments
      testUsingContext('working directory with errors', () async {
        // Break the code to produce the "Avoid empty else" hint
        // that is upgraded to a warning in package:flutter/analysis_options_user.yaml
        // to assert that we are using the default Flutter analysis options.
        // Also insert a statement that should not trigger a lint here
        // but will trigger a lint later on when an analysis_options.yaml is added.
        String source = await libMain.readAsString();
        source = source.replaceFirst(
          'return MaterialApp(',
          'if (debugPrintRebuildDirtyWidgets) {} else ; return MaterialApp(',
        );
        source = source.replaceFirst(
          'onPressed: _incrementCounter,',
          '// onPressed: _incrementCounter,',
        );
        source = source.replaceFirst(
            '_counter++;',
            '_counter++; throw "an error message";',
          );
        libMain.writeAsStringSync(source);

        // Analyze in the current directory - no arguments
        await runCommand(
          command: AnalyzeCommand(workingDirectory: globals.fs.directory(projectPath)),
          arguments: <String>['analyze', '--no-pub'],
          statusTextContains: <String>[
            'Analyzing',
            'info $analyzerSeparator Avoid empty else statements',
            'info $analyzerSeparator Avoid empty statements',
            "info $analyzerSeparator The declaration '_incrementCounter' isn't",
          ],
          exitMessageContains: '3 issues found.',
          toolExit: true,
        );
      });

      // Analyze in the current directory - no arguments
      testUsingContext('working directory with local options', () async {
        // Insert an analysis_options.yaml file in the project
        // which will trigger a lint for broken code that was inserted earlier
        final File optionsFile = globals.fs.file(globals.fs.path.join(projectPath, 'analysis_options.yaml'));
        try {
          optionsFile.writeAsStringSync('''
      include: package:flutter/analysis_options_user.yaml
      linter:
        rules:
          - only_throw_errors
      ''');
          String source = libMain.readAsStringSync();
          source = source.replaceFirst(
            'onPressed: _incrementCounter,',
            '// onPressed: _incrementCounter,',
          );
          source = source.replaceFirst(
            '_counter++;',
            '_counter++; throw "an error message";',
          );
          libMain.writeAsStringSync(source);

          // Analyze in the current directory - no arguments
          await runCommand(
            command: AnalyzeCommand(workingDirectory: globals.fs.directory(projectPath)),
            arguments: <String>['analyze', '--no-pub'],
            statusTextContains: <String>[
              'Analyzing',
              "info $analyzerSeparator The declaration '_incrementCounter' isn't",
              'info $analyzerSeparator Only throw instances of classes extending either Exception or Error',
            ],
            exitMessageContains: '2 issues found.',
            toolExit: true,
          );
        } finally {
          if (optionsFile.existsSync()) {
            optionsFile.deleteSync();
          }
        }
      });
    });

    testUsingContext('no duplicate issues', () async {
      final Directory tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_analyze_once_test_2.').absolute;
      _createDotPackages(tempDir.path);

      try {
        final File foo = globals.fs.file(globals.fs.path.join(tempDir.path, 'foo.dart'));
        foo.writeAsStringSync('''
import 'bar.dart';

void foo() => bar();
''');

        final File bar = globals.fs.file(globals.fs.path.join(tempDir.path, 'bar.dart'));
        bar.writeAsStringSync('''
import 'dart:async'; // unused

void bar() {
}
''');

        // Analyze in the current directory - no arguments
        await runCommand(
          command: AnalyzeCommand(workingDirectory: tempDir),
          arguments: <String>['analyze', '--no-pub'],
          statusTextContains: <String>[
            'Analyzing',
          ],
          exitMessageContains: '1 issue found.',
          toolExit: true,
        );
      } finally {
        tryToDelete(tempDir);
      }
    });

    testUsingContext('returns no issues when source is error-free', () async {
      const String contents = '''
StringBuffer bar = StringBuffer('baz');
''';
      final Directory tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_analyze_once_test_3.');
      _createDotPackages(tempDir.path);

      tempDir.childFile('main.dart').writeAsStringSync(contents);
      try {
        await runCommand(
          command: AnalyzeCommand(workingDirectory: globals.fs.directory(tempDir)),
          arguments: <String>['analyze', '--no-pub'],
          statusTextContains: <String>['No issues found!'],
        );
      } finally {
        tryToDelete(tempDir);
      }
    }, overrides: <Type, Generator>{
      ...noColorTerminalOverride
    });

    testUsingContext('returns no issues for todo comments', () async {
      const String contents = '''
// TODO(foobar):
StringBuffer bar = StringBuffer('baz');
''';
      final Directory tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_analyze_once_test_4.');
      _createDotPackages(tempDir.path);

      tempDir.childFile('main.dart').writeAsStringSync(contents);
      try {
        await runCommand(
          command: AnalyzeCommand(workingDirectory: globals.fs.directory(tempDir)),
          arguments: <String>['analyze', '--no-pub'],
          statusTextContains: <String>['No issues found!'],
        );
      } finally {
        tryToDelete(tempDir);
      }
    }, overrides: <Type, Generator>{
      ...noColorTerminalOverride
    });
  });
}

void assertContains(String text, List<String> patterns) {
  if (patterns == null) {
    expect(text, isEmpty);
  } else {
    for (final String pattern in patterns) {
      expect(text, contains(pattern));
    }
  }
}

Future<void> runCommand({
  FlutterCommand command,
  List<String> arguments,
  List<String> statusTextContains,
  List<String> errorTextContains,
  bool toolExit = false,
  String exitMessageContains,
}) async {
  try {
    arguments.insert(0, '--flutter-root=${Cache.flutterRoot}');
    await createTestCommandRunner(command).run(arguments);
    expect(toolExit, isFalse, reason: 'Expected ToolExit exception');
  } on ToolExit catch (e) {
    if (!toolExit) {
      testLogger.clear();
      rethrow;
    }
    if (exitMessageContains != null) {
      expect(e.message, contains(exitMessageContains));
    }
  }
  assertContains(testLogger.statusText, statusTextContains);
  assertContains(testLogger.errorText, errorTextContains);

  testLogger.clear();
}

const String mainDartSrc = r'''
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
''';

const String pubspecYamlSrc = r'''
name: flutter_project
environment:
  sdk: ">=2.1.0 <3.0.0"

dependencies:
  flutter:
    sdk: flutter
''';
