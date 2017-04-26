// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/usage.dart';
import 'package:flutter_tools/src/base/utils.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../context.dart';

void main() {

  group('Flutter Command', () {

    MockCache cache;
    MockClock clock;
    MockUsage usage;

    setUp(() {
      cache = new MockCache();
      clock = new MockClock();
      usage = new MockUsage();
    });

    testUsingContext('honors shouldUpdateCache false', () async {
      final DummyFlutterCommand flutterCommand = new DummyFlutterCommand(shouldUpdateCache: false);
      await flutterCommand.run();
      verifyZeroInteractions(cache);
    },
    overrides: <Type, Generator>{
      Cache: () => cache,
    });

    testUsingContext('honors shouldUpdateCache true', () async {
      final DummyFlutterCommand flutterCommand = new DummyFlutterCommand(shouldUpdateCache: true);
      await flutterCommand.run();
      verify(cache.updateAll()).called(1);
    },
    overrides: <Type, Generator>{
      Cache: () => cache,
    });

    testUsingContext('report execution timing by default', () async {
      final List<int> mockTimes = <int>[1000, 2000];
      // Crash if called a third time which is unexpected.
      when(clock.now()).thenAnswer(
        (Invocation _) => new DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0))
      );

      final DummyFlutterCommand flutterCommand = new DummyFlutterCommand();
      await flutterCommand.run();
      verify(clock.now()).called(2);

      expect(
        verify(usage.sendTiming(captureAny, captureAny, captureAny, label: captureAny)).captured, 
        <dynamic>['flutter', 'dummy', const Duration(milliseconds: 1000), null]
      );
    },
    overrides: <Type, Generator>{
      Clock: () => clock,
      Usage: () => usage,
    });

    testUsingContext('no timing report without usagePath', () async {
      final List<int> mockTimes = <int>[1000, 2000];
      // Crash if called a third time which is unexpected.
      when(clock.now()).thenAnswer(
        (Invocation _) => new DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0))
      );

      final DummyFlutterCommand flutterCommand = 
          new DummyFlutterCommand(noUsagePath: true);
      await flutterCommand.run();
      verify(clock.now()).called(2);
      verifyNever(usage.sendTiming(captureAny, captureAny, captureAny, label: captureAny));
    },
    overrides: <Type, Generator>{
      Clock: () => clock,
      Usage: () => usage,
    });
    
    testUsingContext('report additional FlutterCommandResult data', () async {
      final List<int> mockTimes = <int>[1000, 2000];
      // Crash if called a third time which is unexpected.
      when(clock.now()).thenAnswer(
        (Invocation _) => new DateTime.fromMillisecondsSinceEpoch(mockTimes.removeAt(0))
      );

      final FlutterCommandResult commandResult = new FlutterCommandResult(
        ExitStatus.fail,
        // nulls should be cleaned up.
        analyticsParameters: <String> ['blah1', 'blah2', null, 'blah3'],
        exitTime: new DateTime.fromMillisecondsSinceEpoch(1500)
      );

      final DummyFlutterCommand flutterCommand = 
          new DummyFlutterCommand(flutterCommandResult: commandResult);
      await flutterCommand.run();
      verify(clock.now()).called(2);
      expect(
        verify(usage.sendTiming(captureAny, captureAny, captureAny, label: captureAny)).captured, 
        <dynamic>[
          'flutter', 
          'dummy', 
          const Duration(milliseconds: 500), // FlutterCommandResult's end time used instead.
          'fail-blah1-blah2-blah3',
        ],
      );    
    },
    overrides: <Type, Generator>{
      Clock: () => clock,
      Usage: () => usage,
    });

  });

}

class DummyFlutterCommand extends FlutterCommand {

  DummyFlutterCommand({
    this.shouldUpdateCache, 
    this.noUsagePath, 
    this.flutterCommandResult
  });

  final bool noUsagePath;
  final FlutterCommandResult flutterCommandResult;

  @override
  final bool shouldUpdateCache;

  @override
  String get description => 'does nothing';

  @override
  String get usagePath => noUsagePath ? null : super.usagePath;

  @override
  String get name => 'dummy';

  @override
  Future<FlutterCommandResult> runCommand() async {
    return flutterCommandResult;
  }
}

class MockCache extends Mock implements Cache {}

class MockUsage extends Mock implements Usage {}