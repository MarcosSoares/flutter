// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:test_api/test_api.dart' as test_package;
import 'package:test_api/src/backend/declarer.dart'; // ignore: implementation_imports
import 'package:test_api/src/frontend/timeout.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group_entry.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/message.dart'; // ignore: implementation_imports

import 'all_elements.dart';
import 'binding.dart';
import 'controller.dart';
import 'finders.dart';
import 'matchers.dart';
import 'test_async_utils.dart';
import 'test_text_input.dart';

/// Keep users from needing multiple imports to test semantics.
export 'package:flutter/rendering.dart' show SemanticsHandle;

export 'package:test_api/test_api.dart' hide
  test,
  group,
  setUpAll,
  tearDownAll,
  setUp,
  tearDown,
  expect, // we have our own wrapper below
  TypeMatcher, // matcher's TypeMatcher conflicts with the one in the Flutter framework
  isInstanceOf; // we have our own wrapper in matchers.dart

/// Signature for callback to [testWidgets] and [benchmarkWidgets].
typedef WidgetTesterCallback = Future<void> Function(WidgetTester widgetTester);

Declarer _localDeclarer;
Declarer get _declarer {
  final Declarer declarer = Zone.current[#test.declarer];
  if (declarer != null) {
    return declarer;
  }
  // If no declarer is defined, this test is being run via `flutter run -t test_file.dart`.
  if (_localDeclarer == null) {
    _localDeclarer = Declarer();
    Future<void>(() async {
      final Group group = _declarer.build();
      final Suite suite = Suite(group, SuitePlatform(Runtime.vm));
      void onMessage(Message message) => print(message.text);
      Future<void> runTest(List<GroupEntry> tests, Group parent) async {
        for (GroupEntry entry in tests) {
          if (entry is Test) {
            final LiveTest liveTest = entry.load(suite);
            liveTest.onMessage.listen(onMessage);
            print('${parent?.name ?? ''}${entry.name}');
            await liveTest.run();
          } else if (entry is Group) {
            if (entry.setUpAll != null) {
              final LiveTest liveTest = entry.setUpAll.load(suite);
              liveTest.onMessage.listen(onMessage);
              await liveTest.run();
            }
            await runTest(entry.entries, entry);
            if (entry.tearDownAll != null) {
              final LiveTest liveTest = entry.tearDownAll.load(suite);
              liveTest.onMessage.listen(onMessage);
              await liveTest.run();
            }
          }
        }
      }
      await runTest(<GroupEntry>[suite.group], null);
    });
  }
  return _localDeclarer;
}

// TODO(nweiz): This and other top-level functions should throw exceptions if
// they're called after the declarer has finished declaring.
/// Creates a new test case with the given description (converted to a string)
/// and body.
///
/// The description will be added to the descriptions of any surrounding
/// [group]s. If [testOn] is passed, it's parsed as a [platform selector][]; the
/// test will only be run on matching platforms.
///
/// [platform selector]: https://github.com/dart-lang/test/tree/master/pkgs/test#platform-selectors
///
/// If [timeout] is passed, it's used to modify or replace the default timeout
/// of 30 seconds. Timeout modifications take precedence in suite-group-test
/// order, so [timeout] will also modify any timeouts set on the group or suite.
///
/// If [skip] is a String or `true`, the test is skipped. If it's a String, it
/// should explain why the test is skipped; this reason will be printed instead
/// of running the test.
///
/// If [tags] is passed, it declares user-defined tags that are applied to the
/// test. These tags can be used to select or skip the test on the command line,
/// or to do bulk test configuration. All tags should be declared in the
/// [package configuration file][configuring tags]. The parameter can be an
/// [Iterable] of tag names, or a [String] representing a single tag.
///
/// If [retry] is passed, the test will be retried the provided number of times
/// before being marked as a failure.
///
/// [configuring tags]: https://github.com/dart-lang/test/blob/master/doc/package_config.md#configuring-tags
///
/// [onPlatform] allows tests to be configured on a platform-by-platform
/// basis. It's a map from strings that are parsed as [PlatformSelector]s to
/// annotation classes: [Timeout], [Skip], or lists of those. These
/// annotations apply only on the given platforms. For example:
///
///     test("potentially slow test", () {
///       // ...
///     }, onPlatform: {
///       // This test is especially slow on Windows.
///       "windows": new Timeout.factor(2),
///       "browser": [
///         new Skip("TODO: add browser support"),
///         // This will be slow on browsers once it works on them.
///         new Timeout.factor(2)
///       ]
///     });
///
/// If multiple platforms match, the annotations apply in order as through
/// they were in nested groups.
///
/// If the `solo` flag is `true`, only tests and groups marked as
/// "solo" will be be run. This only restricts tests *within this test
/// suite*—tests in other suites will run as normal. We recommend that users
/// avoid this flag if possible and instead use the test runner flag `-n` to
/// filter tests by name.
void test(Object description, Function body, {
  String testOn,
  Timeout timeout,
  dynamic skip,
  dynamic tags,
  Map<String, dynamic> onPlatform,
  int retry,
  }) {
  _declarer.test(
    description.toString(), body,
    testOn: testOn,
    timeout: timeout,
    skip: skip,
    onPlatform: onPlatform,
    tags: tags,
    retry: retry,
  );
}

/// Creates a group of tests.
///
/// A group's description (converted to a string) is included in the descriptions
/// of any tests or sub-groups it contains. [setUp] and [tearDown] are also scoped
/// to the containing group.
///
/// If [testOn] is passed, it's parsed as a [platform selector][]; the test will
/// only be run on matching platforms.
///
/// [platform selector]: https://github.com/dart-lang/test/tree/master/pkgs/test#platform-selectors
///
/// If [timeout] is passed, it's used to modify or replace the default timeout
/// of 30 seconds. Timeout modifications take precedence in suite-group-test
/// order, so [timeout] will also modify any timeouts set on the suite, and will
/// be modified by any timeouts set on individual tests.
///
/// If [skip] is a String or `true`, the group is skipped. If it's a String, it
/// should explain why the group is skipped; this reason will be printed instead
/// of running the group's tests.
///
/// If [tags] is passed, it declares user-defined tags that are applied to the
/// test. These tags can be used to select or skip the test on the command line,
/// or to do bulk test configuration. All tags should be declared in the
/// [package configuration file][configuring tags]. The parameter can be an
/// [Iterable] of tag names, or a [String] representing a single tag.
///
/// [configuring tags]: https://github.com/dart-lang/test/blob/master/doc/package_config.md#configuring-tags
///
/// [onPlatform] allows groups to be configured on a platform-by-platform
/// basis. It's a map from strings that are parsed as [PlatformSelector]s to
/// annotation classes: [Timeout], [Skip], or lists of those. These
/// annotations apply only on the given platforms. For example:
///
///     group("potentially slow tests", () {
///       // ...
///     }, onPlatform: {
///       // These tests are especially slow on Windows.
///       "windows": new Timeout.factor(2),
///       "browser": [
///         new Skip("TODO: add browser support"),
///         // They'll be slow on browsers once it works on them.
///         new Timeout.factor(2)
///       ]
///     });
///
/// If multiple platforms match, the annotations apply in order as through
/// they were in nested groups.
///
/// If the `solo` flag is `true`, only tests and groups marked as
/// "solo" will be be run. This only restricts tests *within this test
/// suite*—tests in other suites will run as normal. We recommend that users
/// avoid this flag if possible, and instead use the test runner flag `-n` to
/// filter tests by name.
void group(Object description, Function body) {
  _declarer.group(description.toString(), body);
}

/// Registers a function to be run before tests.
///
/// This function will be called before each test is run. [callback] may be
/// asynchronous; if so, it must return a [Future].
///
/// If this is called within a test group, it applies only to tests in that
/// group. [callback] will be run after any set-up callbacks in parent groups or
/// at the top level.
///
/// Each callback at the top level or in a given group will be run in the order
/// they were declared.
void setUp(Function body) {
  _declarer.setUp(body);
}

/// Registers a function to be run after tests.
///
/// This function will be called after each test is run. [callback] may be
/// asynchronous; if so, it must return a [Future].
///
/// If this is called within a test group, it applies only to tests in that
/// group. [callback] will be run before any tear-down callbacks in parent
/// groups or at the top level.
///
/// Each callback at the top level or in a given group will be run in the
/// reverse of the order they were declared.
///
/// See also [addTearDown], which adds tear-downs to a running test.
void tearDown(Function body) {
  _declarer.tearDown(body);
}

/// Registers a function to be run once before all tests.
///
/// [callback] may be asynchronous; if so, it must return a [Future].
///
/// If this is called within a test group, [callback] will run before all tests
/// in that group. It will be run after any [setUpAll] callbacks in parent
/// groups or at the top level. It won't be run if none of the tests in the
/// group are run.
///
/// **Note**: This function makes it very easy to accidentally introduce hidden
/// dependencies between tests that should be isolated. In general, you should
/// prefer [setUp], and only use [setUpAll] if the callback is prohibitively
/// slow.
void setUpAll(Function body) {
  _declarer.setUpAll(body);
}

/// Registers a function to be run once after all tests.
///
/// If this is called within a test group, [callback] will run after all tests
/// in that group. It will be run before any [tearDownAll] callbacks in parent
/// groups or at the top level. It won't be run if none of the tests in the
/// group are run.
///
/// **Note**: This function makes it very easy to accidentally introduce hidden
/// dependencies between tests that should be isolated. In general, you should
/// prefer [tearDown], and only use [tearDownAll] if the callback is
/// prohibitively slow.
void tearDownAll(Function body) {
  _declarer.tearDownAll(body);
}

/// Runs the [callback] inside the Flutter test environment.
///
/// Use this function for testing custom [StatelessWidget]s and
/// [StatefulWidget]s.
///
/// The callback can be asynchronous (using `async`/`await` or
/// using explicit [Future]s).
///
/// This function uses the [test] function in the test package to
/// register the given callback as a test. The callback, when run,
/// will be given a new instance of [WidgetTester]. The [find] object
/// provides convenient widget [Finder]s for use with the
/// [WidgetTester].
///
/// ## Sample code
///
/// ```dart
///     testWidgets('MyWidget', (WidgetTester tester) async {
///       await tester.pumpWidget(new MyWidget());
///       await tester.tap(find.text('Save'));
///       expect(find.text('Success'), findsOneWidget);
///     });
/// ```
@isTest
void testWidgets(String description, WidgetTesterCallback callback, {
  bool skip = false,
  test_package.Timeout timeout
}) {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
  final WidgetTester tester = WidgetTester._(binding);
  timeout ??= binding.defaultTestTimeout;
  test(
    description,
    () {
      tester._recordNumberOfSemanticsHandles();
      test_package.addTearDown(binding.postTest);
      return binding.runTest(
        () => callback(tester),
        tester._endOfTestVerifications,
        description: description ?? '',
      );
    },
    skip: skip,
    timeout: timeout
  );
}

/// Runs the [callback] inside the Flutter benchmark environment.
///
/// Use this function for benchmarking custom [StatelessWidget]s and
/// [StatefulWidget]s when you want to be able to use features from
/// [TestWidgetsFlutterBinding]. The callback, when run, will be given
/// a new instance of [WidgetTester]. The [find] object provides
/// convenient widget [Finder]s for use with the [WidgetTester].
///
/// The callback can be asynchronous (using `async`/`await` or using
/// explicit [Future]s). If it is, then [benchmarkWidgets] will return
/// a [Future] that completes when the callback's does. Otherwise, it
/// will return a Future that is always complete.
///
/// If the callback is asynchronous, make sure you `await` the call
/// to [benchmarkWidgets], otherwise it won't run!
///
/// Benchmarks must not be run in checked mode. To avoid this, this
/// function will print a big message if it is run in checked mode.
///
/// Example:
///
///     main() async {
///       assert(false); // fail in checked mode
///       await benchmarkWidgets((WidgetTester tester) async {
///         await tester.pumpWidget(new MyWidget());
///         final Stopwatch timer = new Stopwatch()..start();
///         for (int index = 0; index < 10000; index += 1) {
///           await tester.tap(find.text('Tap me'));
///           await tester.pump();
///         }
///         timer.stop();
///         debugPrint('Time taken: ${timer.elapsedMilliseconds}ms');
///       });
///       exit(0);
///     }
Future<void> benchmarkWidgets(WidgetTesterCallback callback) {
  assert(() {
    print('┏╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┓');
    print('┇ ⚠ THIS BENCHMARK IS BEING RUN WITH ASSERTS ENABLED ⚠  ┇');
    print('┡╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍╍┦');
    print('│                                                       │');
    print('│  Numbers obtained from a benchmark while asserts are  │');
    print('│  enabled will not accurately reflect the performance  │');
    print('│  that will be experienced by end users using release  ╎');
    print('│  builds. Benchmarks should be run using this command  ┆');
    print('│  line:  flutter run --release benchmark.dart          ┊');
    print('│                                                        ');
    print('└─────────────────────────────────────────────────╌┄┈  🐢');
    return true;
  }());
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();
  assert(binding is! AutomatedTestWidgetsFlutterBinding);
  final WidgetTester tester = WidgetTester._(binding);
  tester._recordNumberOfSemanticsHandles();
  return binding.runTest(
    () => callback(tester),
    tester._endOfTestVerifications,
  ) ?? Future<void>.value();
}

/// Assert that `actual` matches `matcher`.
///
/// See [test_package.expect] for details. This is a variant of that function
/// that additionally verifies that there are no asynchronous APIs
/// that have not yet resolved.
///
/// See also:
///
///  * [expectLater] for use with asynchronous matchers.
void expect(dynamic actual, dynamic matcher, {
  String reason,
  dynamic skip, // true or a String
}) {
  TestAsyncUtils.guardSync();
  test_package.expect(actual, matcher, reason: reason, skip: skip);
}

/// Assert that `actual` matches `matcher`.
///
/// See [test_package.expect] for details. This variant will _not_ check that
/// there are no outstanding asynchronous API requests. As such, it can be
/// called from, e.g., callbacks that are run during build or layout, or in the
/// completion handlers of futures that execute in response to user input.
///
/// Generally, it is better to use [expect], which does include checks to ensure
/// that asynchronous APIs are not being called.
void expectSync(dynamic actual, dynamic matcher, {
  String reason,
}) {
  test_package.expect(actual, matcher, reason: reason);
}

/// Just like [expect], but returns a [Future] that completes when the matcher
/// has finished matching.
///
/// See [test_package.expectLater] for details.
///
/// If the matcher fails asynchronously, that failure is piped to the returned
/// future where it can be handled by user code. If it is not handled by user
/// code, the test will fail.
Future<void> expectLater(dynamic actual, dynamic matcher, {
  String reason,
  dynamic skip, // true or a String
}) {
  // We can't wrap the delegate in a guard, or we'll hit async barriers in
  // [TestWidgetsFlutterBinding] while we're waiting for the matcher to complete
  TestAsyncUtils.guardSync();
  return test_package.expectLater(actual, matcher, reason: reason, skip: skip)
           .then<void>((dynamic value) => null);
}

/// Class that programmatically interacts with widgets and the test environment.
///
/// For convenience, instances of this class (such as the one provided by
/// `testWidget`) can be used as the `vsync` for `AnimationController` objects.
class WidgetTester extends WidgetController implements HitTestDispatcher, TickerProvider {
  WidgetTester._(TestWidgetsFlutterBinding binding) : super(binding) {
    if (binding is LiveTestWidgetsFlutterBinding)
      binding.deviceEventDispatcher = this;
  }

  /// The binding instance used by the testing framework.
  @override
  TestWidgetsFlutterBinding get binding => super.binding;

  /// Renders the UI from the given [widget].
  ///
  /// Calls [runApp] with the given widget, then triggers a frame and flushes
  /// microtasks, by calling [pump] with the same `duration` (if any). The
  /// supplied [EnginePhase] is the final phase reached during the pump pass; if
  /// not supplied, the whole pass is executed.
  ///
  /// Subsequent calls to this is different from [pump] in that it forces a full
  /// rebuild of the tree, even if [widget] is the same as the previous call.
  /// [pump] will only rebuild the widgets that have changed.
  ///
  /// See also [LiveTestWidgetsFlutterBindingFramePolicy], which affects how
  /// this method works when the test is run with `flutter run`.
  Future<void> pumpWidget(Widget widget, [
    Duration duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]) {
    return TestAsyncUtils.guard<void>(() {
      binding.attachRootWidget(widget);
      binding.scheduleFrame();
      return binding.pump(duration, phase);
    });
  }

  /// Triggers a frame after `duration` amount of time.
  ///
  /// This makes the framework act as if the application had janked (missed
  /// frames) for `duration` amount of time, and then received a v-sync signal
  /// to paint the application.
  ///
  /// This is a convenience function that just calls
  /// [TestWidgetsFlutterBinding.pump].
  ///
  /// See also [LiveTestWidgetsFlutterBindingFramePolicy], which affects how
  /// this method works when the test is run with `flutter run`.
  @override
  Future<void> pump([
    Duration duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]) {
    return TestAsyncUtils.guard<void>(() => binding.pump(duration, phase));
  }

  /// Repeatedly calls [pump] with the given `duration` until there are no
  /// longer any frames scheduled. This will call [pump] at least once, even if
  /// no frames are scheduled when the function is called, to flush any pending
  /// microtasks which may themselves schedule a frame.
  ///
  /// This essentially waits for all animations to have completed.
  ///
  /// If it takes longer that the given `timeout` to settle, then the test will
  /// fail (this method will throw an exception). In particular, this means that
  /// if there is an infinite animation in progress (for example, if there is an
  /// indeterminate progress indicator spinning), this method will throw.
  ///
  /// The default timeout is ten minutes, which is longer than most reasonable
  /// finite animations would last.
  ///
  /// If the function returns, it returns the number of pumps that it performed.
  ///
  /// In general, it is better practice to figure out exactly why each frame is
  /// needed, and then to [pump] exactly as many frames as necessary. This will
  /// help catch regressions where, for instance, an animation is being started
  /// one frame later than it should.
  ///
  /// Alternatively, one can check that the return value from this function
  /// matches the expected number of pumps.
  Future<int> pumpAndSettle([
      Duration duration = const Duration(milliseconds: 100),
      EnginePhase phase = EnginePhase.sendSemanticsUpdate,
      Duration timeout = const Duration(minutes: 10),
    ]) {
    assert(duration != null);
    assert(duration > Duration.zero);
    assert(timeout != null);
    assert(timeout > Duration.zero);
    assert(() {
      final WidgetsBinding binding = this.binding;
      if (binding is LiveTestWidgetsFlutterBinding &&
          binding.framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
        throw 'When using LiveTestWidgetsFlutterBindingFramePolicy.benchmark, '
              'hasScheduledFrame is never set to true. This means that pumpAndSettle() '
              'cannot be used, because it has no way to know if the application has '
              'stopped registering new frames.';
      }
      return true;
    }());
    int count = 0;
    return TestAsyncUtils.guard<void>(() async {
      final DateTime endTime = binding.clock.fromNowBy(timeout);
      do {
        if (binding.clock.now().isAfter(endTime))
          throw FlutterError('pumpAndSettle timed out');
        await binding.pump(duration, phase);
        count += 1;
      } while (binding.hasScheduledFrame);
    }).then<int>((_) => count);
  }

  /// Runs a [callback] that performs real asynchronous work.
  ///
  /// This is intended for callers who need to call asynchronous methods where
  /// the methods spawn isolates or OS threads and thus cannot be executed
  /// synchronously by calling [pump].
  ///
  /// If callers were to run these types of asynchronous tasks directly in
  /// their test methods, they run the possibility of encountering deadlocks.
  ///
  /// If [callback] completes successfully, this will return the future
  /// returned by [callback].
  ///
  /// If [callback] completes with an error, the error will be caught by the
  /// Flutter framework and made available via [takeException], and this method
  /// will return a future that completes will `null`.
  ///
  /// Re-entrant calls to this method are not allowed; callers of this method
  /// are required to wait for the returned future to complete before calling
  /// this method again. Attempts to do otherwise will result in a
  /// [TestFailure] error being thrown.
  Future<T> runAsync<T>(Future<T> callback(), {
    Duration additionalTime = const Duration(milliseconds: 250),
  }) => binding.runAsync<T>(callback, additionalTime: additionalTime);

  /// Whether there are any any transient callbacks scheduled.
  ///
  /// This essentially checks whether all animations have completed.
  ///
  /// See also:
  ///
  ///  * [pumpAndSettle], which essentially calls [pump] until there are no
  ///    scheduled frames.
  ///  * [SchedulerBinding.transientCallbackCount], which is the value on which
  ///    this is based.
  ///  * [SchedulerBinding.hasScheduledFrame], which is true whenever a frame is
  ///    pending. [SchedulerBinding.hasScheduledFrame] is made true when a
  ///    widget calls [State.setState], even if there are no transient callbacks
  ///    scheduled. This is what [pumpAndSettle] uses.
  bool get hasRunningAnimations => binding.transientCallbackCount > 0;

  @override
  HitTestResult hitTestOnBinding(Offset location) {
    location = binding.localToGlobal(location);
    return super.hitTestOnBinding(location);
  }

  @override
  Future<void> sendEventToBinding(PointerEvent event, HitTestResult result) {
    return TestAsyncUtils.guard<void>(() async {
      binding.dispatchEvent(event, result, source: TestBindingEventSource.test);
    });
  }

  /// Handler for device events caught by the binding in live test mode.
  @override
  void dispatchEvent(PointerEvent event, HitTestResult result) {
    if (event is PointerDownEvent) {
      final RenderObject innerTarget = result.path.firstWhere(
        (HitTestEntry candidate) => candidate.target is RenderObject,
      ).target;
      final Element innerTargetElement = collectAllElementsFrom(
        binding.renderViewElement,
        skipOffstage: true,
      ).lastWhere(
        (Element element) => element.renderObject == innerTarget,
        orElse: () => null,
      );
      if (innerTargetElement == null) {
        debugPrint('No widgets found at ${binding.globalToLocal(event.position)}.');
        return;
      }
      final List<Element> candidates = <Element>[];
      innerTargetElement.visitAncestorElements((Element element) {
        candidates.add(element);
        return true;
      });
      assert(candidates.isNotEmpty);
      String descendantText;
      int numberOfWithTexts = 0;
      int numberOfTypes = 0;
      int totalNumber = 0;
      debugPrint('Some possible finders for the widgets at ${binding.globalToLocal(event.position)}:');
      for (Element element in candidates) {
        if (totalNumber > 13) // an arbitrary number of finders that feels useful without being overwhelming
          break;
        totalNumber += 1; // optimistically assume we'll be able to describe it

        if (element.widget is Tooltip) {
          final Tooltip widget = element.widget;
          final Iterable<Element> matches = find.byTooltip(widget.message).evaluate();
          if (matches.length == 1) {
            debugPrint('  find.byTooltip(\'${widget.message}\')');
            continue;
          }
        }

        if (element.widget is Text) {
          assert(descendantText == null);
          final Text widget = element.widget;
          final Iterable<Element> matches = find.text(widget.data).evaluate();
          descendantText = widget.data;
          if (matches.length == 1) {
            debugPrint('  find.text(\'${widget.data}\')');
            continue;
          }
        }

        if (element.widget.key is ValueKey<dynamic>) {
          final ValueKey<dynamic> key = element.widget.key;
          String keyLabel;
          if (key is ValueKey<int> ||
              key is ValueKey<double> ||
              key is ValueKey<bool>) {
            keyLabel = 'const ${element.widget.key.runtimeType}(${key.value})';
          } else if (key is ValueKey<String>) {
            keyLabel = 'const Key(\'${key.value}\')';
          }
          if (keyLabel != null) {
            final Iterable<Element> matches = find.byKey(key).evaluate();
            if (matches.length == 1) {
              debugPrint('  find.byKey($keyLabel)');
              continue;
            }
          }
        }

        if (!_isPrivate(element.widget.runtimeType)) {
          if (numberOfTypes < 5) {
            final Iterable<Element> matches = find.byType(element.widget.runtimeType).evaluate();
            if (matches.length == 1) {
              debugPrint('  find.byType(${element.widget.runtimeType})');
              numberOfTypes += 1;
              continue;
            }
          }

          if (descendantText != null && numberOfWithTexts < 5) {
            final Iterable<Element> matches = find.widgetWithText(element.widget.runtimeType, descendantText).evaluate();
            if (matches.length == 1) {
              debugPrint('  find.widgetWithText(${element.widget.runtimeType}, \'$descendantText\')');
              numberOfWithTexts += 1;
              continue;
            }
          }
        }

        if (!_isPrivate(element.runtimeType)) {
          final Iterable<Element> matches = find.byElementType(element.runtimeType).evaluate();
          if (matches.length == 1) {
            debugPrint('  find.byElementType(${element.runtimeType})');
            continue;
          }
        }

        totalNumber -= 1; // if we got here, we didn't actually find something to say about it
      }
      if (totalNumber == 0)
        debugPrint('  <could not come up with any unique finders>');
    }
  }

  bool _isPrivate(Type type) {
    // used above so that we don't suggest matchers for private types
    return '_'.matchAsPrefix(type.toString()) != null;
  }

  /// Returns the exception most recently caught by the Flutter framework.
  ///
  /// See [TestWidgetsFlutterBinding.takeException] for details.
  dynamic takeException() {
    return binding.takeException();
  }

  /// Acts as if the application went idle.
  ///
  /// Runs all remaining microtasks, including those scheduled as a result of
  /// running them, until there are no more microtasks scheduled.
  ///
  /// Does not run timers. May result in an infinite loop or run out of memory
  /// if microtasks continue to recursively schedule new microtasks.
  Future<void> idle() {
    return TestAsyncUtils.guard<void>(() => binding.idle());
  }

  Set<Ticker> _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    _tickers ??= Set<_TestTicker>();
    final _TestTicker result = _TestTicker(onTick, _removeTicker);
    _tickers.add(result);
    return result;
  }

  void _removeTicker(_TestTicker ticker) {
    assert(_tickers != null);
    assert(_tickers.contains(ticker));
    _tickers.remove(ticker);
  }

  /// Throws an exception if any tickers created by the [WidgetTester] are still
  /// active when the method is called.
  ///
  /// An argument can be specified to provide a string that will be used in the
  /// error message. It should be an adverbial phrase describing the current
  /// situation, such as "at the end of the test".
  void verifyTickersWereDisposed([ String when = 'when none should have been' ]) {
    assert(when != null);
    if (_tickers != null) {
      for (Ticker ticker in _tickers) {
        if (ticker.isActive) {
          throw FlutterError(
            'A Ticker was active $when.\n'
            'All Tickers must be disposed. Tickers used by AnimationControllers '
            'should be disposed by calling dispose() on the AnimationController itself. '
            'Otherwise, the ticker will leak.\n'
            'The offending ticker was: ${ticker.toString(debugIncludeStack: true)}'
          );
        }
      }
    }
  }

  void _endOfTestVerifications() {
    verifyTickersWereDisposed('at the end of the test');
    _verifySemanticsHandlesWereDisposed();
  }

  void _verifySemanticsHandlesWereDisposed() {
    assert(_lastRecordedSemanticsHandles != null);
    if (binding.pipelineOwner.debugOutstandingSemanticsHandles > _lastRecordedSemanticsHandles) {
      throw FlutterError(
        'A SemanticsHandle was active at the end of the test.\n'
        'All SemanticsHandle instances must be disposed by calling dispose() on '
        'the SemanticsHandle. If your test uses SemanticsTester, it is '
        'sufficient to call dispose() on SemanticsTester. Otherwise, the '
        'existing handle will leak into another test and alter its behavior.'
      );
    }
    _lastRecordedSemanticsHandles = null;
  }

  int _lastRecordedSemanticsHandles;

  void _recordNumberOfSemanticsHandles() {
    _lastRecordedSemanticsHandles = binding.pipelineOwner.debugOutstandingSemanticsHandles;
  }

  /// Returns the TestTextInput singleton.
  ///
  /// Typical app tests will not need to use this value. To add text to widgets
  /// like [TextField] or [TextFormField], call [enterText].
  TestTextInput get testTextInput => binding.testTextInput;

  /// Give the text input widget specified by [finder] the focus, as if the
  /// onscreen keyboard had appeared.
  ///
  /// Implies a call to [pump].
  ///
  /// The widget specified by [finder] must be an [EditableText] or have
  /// an [EditableText] descendant. For example `find.byType(TextField)`
  /// or `find.byType(TextFormField)`, or `find.byType(EditableText)`.
  ///
  /// Tests that just need to add text to widgets like [TextField]
  /// or [TextFormField] only need to call [enterText].
  Future<void> showKeyboard(Finder finder) async {
    return TestAsyncUtils.guard<void>(() async {
      final EditableTextState editable = state<EditableTextState>(
        find.descendant(
          of: finder,
          matching: find.byType(EditableText),
          matchRoot: true,
        ),
      );
      binding.focusedEditable = editable;
      await pump();
    });
  }

  /// Give the text input widget specified by [finder] the focus and
  /// enter [text] as if it been provided by the onscreen keyboard.
  ///
  /// The widget specified by [finder] must be an [EditableText] or have
  /// an [EditableText] descendant. For example `find.byType(TextField)`
  /// or `find.byType(TextFormField)`, or `find.byType(EditableText)`.
  ///
  /// To just give [finder] the focus without entering any text,
  /// see [showKeyboard].
  Future<void> enterText(Finder finder, String text) async {
    return TestAsyncUtils.guard<void>(() async {
      await showKeyboard(finder);
      testTextInput.enterText(text);
      await idle();
    });
  }

  /// Makes an effort to dismiss the current page with a Material [Scaffold] or
  /// a [CupertinoPageScaffold].
  ///
  /// Will throw an error if there is no back button in the page.
  Future<void> pageBack() async {
    return TestAsyncUtils.guard<void>(() async {
      Finder backButton = find.byTooltip('Back');
      if (backButton.evaluate().isEmpty) {
        backButton = find.byType(CupertinoNavigationBarBackButton);
      }

      expectSync(backButton, findsOneWidget, reason: 'One back button expected on screen');

      await tap(backButton);
    });
  }

  /// Attempts to find the [SemanticsNode] of first result from `finder`.
  ///
  /// If the object identified by the finder doesn't own it's semantic node,
  /// this will return the semantics data of the first ancestor with semantics.
  /// The ancestor's semantic data will include the child's as well as
  /// other nodes that have been merged together.
  ///
  /// Will throw a [StateError] if the finder returns more than one element or
  /// if no semantics are found or are not enabled.
  SemanticsNode getSemantics(Finder finder) {
    if (binding.pipelineOwner.semanticsOwner == null)
      throw StateError('Semantics are not enabled.');
    final Iterable<Element> candidates = finder.evaluate();
    if (candidates.isEmpty) {
      throw StateError('Finder returned no matching elements.');
    }
    if (candidates.length > 1) {
      throw StateError('Finder returned more than one element.');
    }
    final Element element = candidates.single;
    RenderObject renderObject = element.findRenderObject();
    SemanticsNode result = renderObject.debugSemantics;
    while (renderObject != null && result == null) {
      renderObject = renderObject?.parent;
      result = renderObject?.debugSemantics;
    }
    if (result == null)
      throw StateError('No Semantics data found.');
    return result;
  }

  /// Enable semantics in a test by creating a [SemanticsHandle].
  ///
  /// The handle must be disposed at the end of the test.
  SemanticsHandle ensureSemantics() {
    return binding.pipelineOwner.ensureSemantics();
  }

  /// Given a widget `W` specified by [finder] and a [Scrollable] widget `S` in
  /// its ancestry tree, this scrolls `S` so as to make `W` visible.
  ///
  /// Shorthand for `Scrollable.ensureVisible(tester.element(finder))`
  Future<void> ensureVisible(Finder finder) => Scrollable.ensureVisible(element(finder));
}

typedef _TickerDisposeCallback = void Function(_TestTicker ticker);

class _TestTicker extends Ticker {
  _TestTicker(TickerCallback onTick, this._onDispose) : super(onTick);

  _TickerDisposeCallback _onDispose;

  @override
  void dispose() {
    if (_onDispose != null)
      _onDispose(this);
    super.dispose();
  }
}
